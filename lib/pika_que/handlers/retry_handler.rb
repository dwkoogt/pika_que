module PikaQue
  module Handlers
    class RetryHandler

      # Create following exchanges with retry_prefix = pika-que
      # pika-que-retry
      # pika-que-retry-requeue
      # pika-que-error
      # and following queues
      # pika-que-retry-60 (default for const mode)
      # pika-que-retry-120
      # pika-que-retry-240
      # pika-que-retry-480
      # pika-que-retry-960
      #
      # retry_mode can be either :exp or :const

      DEFAULT_RETRY_OPTS = {
        :retry_prefix             => 'pika-que',
        :retry_mode               => :exp,
        :retry_max_times          => 5,
        :retry_backoff_base       => 0,
        :retry_backoff_multiplier => 1000,
        :retry_const_backoff      => 60
      }.freeze

      def initialize(opts = {})
        @opts = PikaQue.config.merge(DEFAULT_RETRY_OPTS).merge(opts)
        @connection = opts[:connection] || PikaQue.connection
        @channel = @connection.create_channel
        @retry_monitor = Monitor.new
        @error_monitor = Monitor.new

        @max_retries = @opts[:retry_max_times]
        @backoff_base = @opts[:retry_backoff_base]
        @backoff_multiplier = @opts[:retry_backoff_multiplier] # This is for example/dev/test

        @retry_name = "#{@opts[:retry_prefix]}-retry"
        @requeue_name = "#{@opts[:retry_prefix]}-retry-requeue"
        @error_name = "#{@opts[:retry_prefix]}-error"

        setup_exchanges
        setup_queues
      end

      def bind_queue(queue, routing_key)
        # bind the worker queue to requeue exchange
        queue.bind(@requeue_exchange, :routing_key => routing_key)
      end

      def handle(response_code, channel, delivery_info, metadata, msg, error = nil)
        case response_code
        when :ack
          PikaQue.logger.debug "RetryHandler acknowledge <#{msg}>"
          channel.acknowledge(delivery_info.delivery_tag, false)
        when :reject
          PikaQue.logger.debug "RetryHandler reject retry <#{msg}>"
          handle_retry(channel, delivery_info, metadata, msg, :reject)
        when :requeue
          PikaQue.logger.debug "RetryHandler requeue <#{msg}>"
          channel.reject(delivery_info.delivery_tag, true)
        else
          PikaQue.logger.debug "RetryHandler error retry <#{msg}>"
          handle_retry(channel, delivery_info, metadata, msg, error)
        end
      end

      def close
        @channel.close unless @channel.closed?
      end


      #####################################################
      # formula
      # base X = 0, 15(2x), 30(3x), 45(4x), 60(5x), 120, 180, etc defaults to 0
      # (X + 15) * 2 ** (count + 1)
      def self.backoff_periods(max_retries, backoff_base)
        (1..max_retries).map{ |c| next_ttl(c, backoff_base) }
      end

      def self.next_ttl(count, backoff_base)
        (backoff_base + 15) * 2 ** (count + 1)
      end

      private

      def setup_exchanges
        PikaQue.logger.debug "RetryHandler creating exchange=#{@retry_name}"
        @retry_exchange = @channel.exchange(@retry_name, :type => 'headers', :durable => exchange_durable?)
        @error_exchange, @requeue_exchange = [@error_name, @requeue_name].map do |name|
          PikaQue.logger.debug "RetryHandler creating exchange=#{name}"
          @channel.exchange(name, :type => 'topic', :durable => exchange_durable?)
        end
      end

      def setup_queues
        if @opts[:retry_mode] == :const
          backoffs = [@opts[:retry_const_backoff]]
        else
          backoffs = RetryHandler.backoff_periods(@max_retries, @backoff_base)
        end

        backoffs.each do |bo|
          PikaQue.logger.debug "RetryHandler creating queue=#{@retry_name}-#{bo} x-dead-letter-exchange=#{@requeue_name}"
          backoff_queue = @channel.queue("#{@retry_name}-#{bo}",
                                        :durable => queue_durable?,
                                        :arguments => {
                                          :'x-dead-letter-exchange' => @requeue_name,
                                          :'x-message-ttl' => bo * @backoff_multiplier
                                        })
          backoff_queue.bind(@retry_exchange, :arguments => { :backoff => bo })
        end

        PikaQue.logger.debug "RetryHandler creating queue=#{@error_name}"
        @error_queue = @channel.queue(@error_name, :durable => queue_durable?)
        @error_queue.bind(@error_exchange, :routing_key => '#')
      end

      def queue_durable?
        @opts.fetch(:queue_options, {}).fetch(:durable, false)
      end

      def exchange_durable?
        @opts.fetch(:exchange_options, {}).fetch(:durable, false)
      end

      def handle_retry(channel, delivery_info, metadata, msg, reason)
        # +1 for the current attempt
        num_attempts = failure_count(metadata[:headers]) + 1
        if num_attempts <= @max_retries
          # Publish message to the x-dead-letter-exchange (ie. retry exchange)
          PikaQue.logger.info "RetryHandler msg=retrying, count=#{num_attempts}, headers=#{metadata[:headers] || {}}"
          
          if @opts[:retry_mode] == :exp
            backoff_ttl = RetryHandler.next_ttl(num_attempts, @backoff_base)
          else
            backoff_ttl = @opts[:retry_const_backoff]
          end

          publish_retry(delivery_info, msg, { backoff: backoff_ttl, count: num_attempts })
          channel.reject(delivery_info.delivery_tag, false)
        else
          PikaQue.logger.info "RetryHandler msg=failing, retried_count=#{num_attempts - 1}, headers=#{metadata[:headers]}, reason=#{reason}"

          publish_error(delivery_info, msg)
          channel.reject(delivery_info.delivery_tag, false)
        end
      end

      # Uses the header to determine the number of failures this job has
      # seen in the past. This does not count the current failure. So for
      # instance, the first time the job fails, this will return 0, the second
      # time, 1, etc.
      # @param headers [Hash] Hash of headers that Rabbit delivers as part of
      #   the message
      # @return [Integer] Count of number of failures.
      def failure_count(headers)
        if headers.nil? || headers['count'].nil?
          0
        else
          headers['count']
        end
      end

      def publish_retry(delivery_info, msg, headers)
        @retry_monitor.synchronize do
          @retry_exchange.publish(msg, routing_key: delivery_info.routing_key, headers: headers)
        end
      end

      def publish_error(delivery_info, msg)
        @error_monitor.synchronize do
          @error_exchange.publish(msg, routing_key: delivery_info.routing_key)
        end
      end

    end
  end
end
