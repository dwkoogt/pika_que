module Fluffy
  module Handlers
    class ErrorHandler

      DEFAULT_ERROR_OPTS = {
        :exchange     => 'fluffy-error',
        :exchange_options => { :type => :topic },
        :queue        => 'fluffy-error',
        :routing_key  => '#'
      }.freeze
     
      def initialize(opts = {})
        opts = Fluffy.config.merge(DEFAULT_ERROR_OPTS).merge(opts)
        @connection = opts[:connection] || Fluffy.connection
        @channel = @connection.create_channel
        @exchange = @channel.exchange(opts[:exchange], opts[:exchange_options])
        @queue = @channel.queue(opts[:queue], opts[:queue_options])
        @queue.bind(@exchange, routing_key: opts[:routing_key])
        @monitor = Monitor.new
      end

      def handle(response_code, channel, delivery_info, metadata, msg, error = nil)
        case response_code
        when :ack
          Fluffy.logger.debug "acknowledge <#{msg}>"
          channel.acknowledge(delivery_info.delivery_tag, false)
        when :reject
          Fluffy.logger.debug "reject <#{msg}>"
          channel.reject(delivery_info.delivery_tag, false)
        when :requeue
          Fluffy.logger.debug "requeue <#{msg}>"
          channel.reject(delivery_info.delivery_tag, true)
        else
          Fluffy.logger.debug "publishing <#{msg}> to [#{@queue.name}]"
          publish(delivery_info, msg)
          channel.acknowledge(delivery_info.delivery_tag, false)
        end
      end

      def publish(delivery_info, msg)
        @monitor.synchronize do
          @exchange.publish(msg, routing_key: delivery_info.routing_key)
        end
      end

      def close
        @channel.close
      end

    end    
  end
end
