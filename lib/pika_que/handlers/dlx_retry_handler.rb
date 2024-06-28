module PikaQue
  module Handlers
    class DLXRetryHandler

      # Create following exchanges with retry_prefix = pika-que and default backoff
      # pika-que-retry-60
      # pika-que-retry-requeue
      # pika-que-error
      # and following queue
      # pika-que-retry-60 (with default backoff)
      #

      DEFAULT_RETRY_OPTS = {
        :retry_prefix             => 'pika-que',
        :retry_max_times          => 5,
        :retry_backoff            => 60,
        :retry_backoff_multiplier => 1000,
      }.freeze

      def initialize(opts = {})
        @opts = PikaQue.config.merge(DEFAULT_RETRY_OPTS).merge(opts)
        @connection = opts[:connection] || PikaQue.connection
        @channel = @connection.create_channel
        @error_monitor = Monitor.new

        @max_retries = @opts[:retry_max_times]
        @backoff_multiplier = @opts[:retry_backoff_multiplier] # This is for example/dev/test

        @retry_ex_name = @opts[:retry_dlx] || "#{@opts[:retry_prefix]}-retry-#{@opts[:retry_backoff]}"
        @retry_name = "#{@opts[:retry_prefix]}-retry"
        @requeue_name = "#{@opts[:retry_prefix]}-retry-requeue"
        @error_name = "#{@opts[:retry_prefix]}-error"

        @queue_name_lookup = {}

        setup_exchanges
        setup_queues
      end

      def bind_queue(queue, routing_key)
        # bind the worker queue to requeue exchange
        @queue_name_lookup[routing_key] = queue.name
        queue.bind(@requeue_exchange, :routing_key => routing_key)
      end

      def handle(response_code, channel, delivery_info, metadata, msg, error = nil)
        case response_code
        when :ack
          PikaQue.logger.debug "DLXRetryHandler acknowledge <#{msg}>"
          channel.acknowledge(delivery_info.delivery_tag, false)
        when :reject
          PikaQue.logger.debug "DLXRetryHandler reject retry <#{msg}>"
          handle_retry(channel, delivery_info, metadata, msg, :reject)
        when :requeue
          PikaQue.logger.debug "DLXRetryHandler requeue <#{msg}>"
          channel.reject(delivery_info.delivery_tag, true)
        else
          PikaQue.logger.debug "DLXRetryHandler error retry <#{msg}>"
          handle_retry(channel, delivery_info, metadata, msg, error)
        end
      end

      def close
        @channel.close unless @channel.closed?
      end

      private

      def setup_exchanges
        @retry_exchange, @error_exchange, @requeue_exchange = [@retry_ex_name, @error_name, @requeue_name].map do |name|
          PikaQue.logger.debug "DLXRetryHandler creating exchange=#{name}"
          @channel.exchange(name, :type => 'topic', :durable => exchange_durable?)
        end
      end

      def setup_queues
        bo = @opts[:retry_backoff]

        PikaQue.logger.debug "DLXRetryHandler creating queue=#{@retry_name}-#{bo} x-dead-letter-exchange=#{@requeue_name}"
        backoff_queue = @channel.queue("#{@retry_name}-#{bo}",
                                      :durable => queue_durable?,
                                      :arguments => {
                                        :'x-dead-letter-exchange' => @requeue_name,
                                        :'x-message-ttl' => bo * @backoff_multiplier
                                      })
        backoff_queue.bind(@retry_exchange, :routing_key => '#')

        PikaQue.logger.debug "DLXRetryHandler creating queue=#{@error_name}"
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
        num_attempts = failure_count(metadata[:headers], delivery_info) + 1
        if num_attempts <= @max_retries
          # Publish message to the x-dead-letter-exchange (ie. retry exchange)
          PikaQue.logger.info "DLXRetryHandler msg=retrying, count=#{num_attempts}, headers=#{metadata[:headers] || {}}"
          
          channel.reject(delivery_info.delivery_tag, false)
        else
          PikaQue.logger.info "DLXRetryHandler msg=failing, retried_count=#{num_attempts - 1}, headers=#{metadata[:headers]}, reason=#{reason}"

          publish_error(delivery_info, msg)
          channel.acknowledge(delivery_info.delivery_tag, false)
        end
      end

      # Uses the x-death header to determine the number of failures this job has
      # seen in the past. This does not count the current failure. So for
      # instance, the first time the job fails, this will return 0, the second
      # time, 1, etc.
      # @param headers [Hash] Hash of headers that Rabbit delivers as part of
      #   the message
      # @return [Integer] Count of number of failures.
      def failure_count(headers, delivery_info)
        if headers.nil? || headers['x-death'].nil?
          0
        else
          queue_name = headers['x-first-death-queue'] || @queue_name_lookup[delivery_info.routing_key]
          x_death_array = headers['x-death'].select do |x_death|
            x_death['queue'] == queue_name
          end
          if x_death_array.count > 0 && x_death_array.first['count']
            # Newer versions of RabbitMQ return headers with a count key
            x_death_array.inject(0) {|sum, x_death| sum + x_death['count']}
          else
            # Older versions return a separate x-death header for each failure
            x_death_array.count
          end
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
