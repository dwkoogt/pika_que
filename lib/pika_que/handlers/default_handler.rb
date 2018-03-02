module PikaQue
  module Handlers
    class DefaultHandler
     
      def initialize(opts = {})
        # nothing to do here
      end

      def bind_queue(queue, routing_key)
      end

      def handle(response_code, channel, delivery_info, metadata, msg, error = nil)
        case response_code
        when :ack
          PikaQue.logger.debug "DefaultHandler acknowledge <#{msg}>"
          channel.acknowledge(delivery_info.delivery_tag, false)
        when :requeue
          PikaQue.logger.debug "DefaultHandler requeue <#{msg}>"
          channel.reject(delivery_info.delivery_tag, true)
        else
          PikaQue.logger.debug "DefaultHandler reject <#{msg}>"
          channel.reject(delivery_info.delivery_tag, false)
        end
      end

      def close
      end

    end    
  end
end
