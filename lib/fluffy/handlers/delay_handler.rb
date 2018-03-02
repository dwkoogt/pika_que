module Fluffy
  module Handlers
    class DelayHandler

      # Create following exchanges with delay_name = fluffy-delay
      # fluffy-delay
      # fluffy-delay-requeue
      # and following queues
      # fluffy-delay-60
      # fluffy-delay-600
      # fluffy-delay-3600
      # fluffy-delay-86400
      #

      # default delays are 1min, 10min, 1hr, 24hr
      DEFAULT_DELAY_OPTS = {
        :delay_periods            => [60, 600, 3600, 86400],
        :delay_backoff_multiplier => 1000,
      }.freeze

      def initialize(opts = {})
        @opts = Fluffy.config.merge(DEFAULT_DELAY_OPTS).merge(opts)
        @connection = opts[:connection] || Fluffy.connection
        @channel = @connection.create_channel
        @delay_monitor = Monitor.new
        @root_monitor = Monitor.new

        # make sure it is in descending order
        @delay_periods = @opts[:delay_periods].sort!{ |x,y| y <=> x }
        @backoff_multiplier = @opts[:delay_backoff_multiplier] # This is for example/dev/test

        @delay_name = "#{@opts[:exchange]}-delay"
        @requeue_name = "#{@opts[:exchange]}-delay-requeue"
        @root_name = @opts[:exchange]

        setup_exchanges
        setup_queues
      end

      def bind_queue(queue, routing_key)
        # bind the worker queue to requeue exchange
        queue.bind(@requeue_exchange, :routing_key => routing_key)
      end

      def handle(response_code, channel, delivery_info, metadata, msg, error = nil)
        delay_period = next_delay_period(metadata[:headers])
        if delay_period > 0
          # We will publish the message to the delay exchange              
          Fluffy.logger.info "DelayHandler msg=delaying, delay=#{delay_period}, headers=#{metadata[:headers]}"

          publish_delay(delivery_info, msg, metadata[:headers].merge({ 'delay' => delay_period }))
          channel.acknowledge(delivery_info.delivery_tag, false)
        else
          # Publish the original message with the routing_key to the root exchange
          work_queue = metadata[:headers]['work_queue']
          Fluffy.logger.info "DelayHandler msg=publishing, queue=#{work_queue}, headers=#{metadata[:headers]}"

          publish_work(work_queue, msg)
          channel.acknowledge(delivery_info.delivery_tag, false)
        end
      end

      def close
        @channel.close unless @channel.closed?
      end

      private

      def setup_exchanges
        Fluffy.logger.debug "DelayHandler creating exchange=#{@delay_name}"
        @delay_exchange = @channel.exchange(@delay_name, :type => 'headers', :durable => exchange_durable?)

        Fluffy.logger.debug "DelayHandler creating exchange=#{@requeue_name}"
        @requeue_exchange = @channel.exchange(@requeue_name, :type => 'topic', :durable => exchange_durable?)

        Fluffy.logger.debug "DelayHandler getting exchange=#{@root_name}"
        @root_exchange = @channel.exchange(@root_name, :type => 'direct', :durable => exchange_durable?)
      end

      def setup_queues
        @delay_periods.each do |t|
          # Create the queues and bindings
          Fluffy.logger.debug "DelayHandler creating queue=#{@delay_name}-#{t} x-dead-letter-exchange=#{@requeue_name}"
          
          delay_queue = @channel.queue("#{@delay_name}-#{t}", 
                                      :durable => queue_durable?,
                                      :arguments => {
                                        :'x-dead-letter-exchange' => @requeue_name,
                                        :'x-message-ttl' => t * @backoff_multiplier
                                      })
          delay_queue.bind(@delay_exchange, :arguments => { :delay => t })
        end
      end

      def queue_durable?
        @opts.fetch(:queue_options, {}).fetch(:durable, false)
      end

      def exchange_durable?
        @opts.fetch(:exchange_options, {}).fetch(:durable, false)
      end

      def publish_delay(delivery_info, msg, headers)
        @delay_monitor.synchronize do
          @delay_exchange.publish(msg, routing_key: delivery_info.routing_key, headers: headers)
        end
      end

      def publish_work(routing_key, msg)
        @root_monitor.synchronize do
          @root_exchange.publish(msg, routing_key: routing_key)
        end
      end

      def next_delay_period(headers)
        work_at = headers['work_at']
        t = (work_at - Time.now.to_f).round
        # greater check is to ignore remainder of time (seconds) smaller than the last delay
        @delay_periods.bsearch{ |e| t >= e && (t / e.to_f).round > 0 } || 0
      end

    end
  end
end
