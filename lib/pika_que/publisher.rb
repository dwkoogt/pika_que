require 'pika_que/util'

module PikaQue
  class Publisher

    def initialize(opts = {})
      @opts = PikaQue.config.merge(opts) 
      @codec = PikaQue::Util.constantize(@opts[:codec])
      @connection = @opts[:connection] || PikaQue.connection
      @channel = @connection.create_channel
      @exchange = @channel.exchange(@opts[:exchange], @opts[:exchange_options])
    end

    def publish(msg, options = {})
      to_queue = options.delete(:to_queue)
      options[:routing_key] ||= to_queue
      options[:content_type] ||= @codec.content_type
      msg = @codec.encode(msg)
      
      PikaQue.logger.info {"publishing <#{msg}> to [#{options[:routing_key]}]"}
      @exchange.publish(msg, options)
    end

  end
end
