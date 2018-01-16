require 'fluffy/util'
require 'fluffy/handlers/default_handler'

module Fluffy
  class Broker

    def initialize(processor = nil, opts = {})
      @opts = Fluffy.config.merge(opts)
      @processor = processor
      @handlers = {}
    end

    def start
      @connection ||= @opts[:connection_options] ? Fluffy::Connection.create(@opts[:connection_options]) : Fluffy.connection
      @connection.ensure_connection
    end

    def stop
      @connection.disconnect! if local_connection?
    end

    def local_connection?
      @opts[:connection_options] || @processor.nil?
    end

    def queue(queue_name, queue_opts)
      queue = channel.queue(queue_name, queue_opts)
      routing_key = queue_opts[:routing_key] || queue_name
      routing_keys = [routing_key, *queue_opts[:routing_keys]]

      routing_keys.each do |key|
        queue.bind(exchange, routing_key: key)
      end
      queue
    end

    def handler(handler_class, handler_opts)
      if handler_class
        h_key = "#{handler_class}-#{handler_opts.hash}"
        _handler = @handlers[h_key]
        unless _handler
          _handler = handler_class.new(handler_opts.merge({ connection: @connection }))
          @handlers[h_key] = _handler
        end
        _handler
      else
        default_handler
      end
    end

    def default_handler
      @default_handler ||= @opts[:handler_class] ? Fluffy::Util.constantize(@opts[:handler_class]).new(@opts[:handler_options].merge({ connection: @connection })) : Fluffy::Handlers::DefaultHandler.new
    end

    def exchange
      @exchange ||= channel.exchange(@opts[:exchange], @opts[:exchange_options])
    end

    def channel
      @channel ||= @opts[:channel] || init_channel
    end

    def init_channel
      @connection.create_channel(nil, @opts[:channel_options][:consumer_pool_size]).tap do |ch|
        ch.prefetch(@opts[:channel_options][:prefetch])
      end
    end

    def cleanup(force = false)
      if (@processor && force) || !@processor
        @channel.close
        @channel = nil
        @exchange = nil
        if @default_handler
          @default_handler.close
          @default_handler = nil
        end
        @handlers.values.each(&:close)
      end
    end

  end
end
