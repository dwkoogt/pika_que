module Fluffy
  module Handlers
    class DefaultHandler
     
      def initialize(opts = {})
        # nothing to do here
      end

      def handle(response_code, channel, delivery_info, metadata, msg, error = nil)
        case response_code
        when :ack
          Fluffy.logger.debug "acknowledge <#{msg}>"
          channel.acknowledge(delivery_info.delivery_tag, false)
        when :requeue
          Fluffy.logger.debug "requeue <#{msg}>"
          channel.reject(delivery_info.delivery_tag, true)
        else
          Fluffy.logger.debug "reject <#{msg}>"
          channel.reject(delivery_info.delivery_tag, false)
        end
      end

      def close
      end

    end    
  end
end
