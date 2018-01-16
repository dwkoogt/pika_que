module Fluffy
  class Publisher

    def initialize(opts = {})
      @opts = Fluffy.config.merge(opts)
      @connection = @opts[:connection] || Fluffy.connection
      @channel = @connection.create_channel
      @exchange = @channel.exchange(@opts[:exchange], @opts[:exchange_options])
    end

    def publish(msg, options = {})
      to_queue = options.delete(:to_queue)
      codec = @opts[:codec]
      options[:routing_key] ||= to_queue
      options[:content_type] ||= codec.content_type
      msg = codec.encode(msg)
      
      Fluffy.logger.info {"publishing <#{msg}> to [#{options[:routing_key]}]"}
      @exchange.publish(msg, options)
    end

  end
end
