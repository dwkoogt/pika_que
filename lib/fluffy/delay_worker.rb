module Fluffy
  class DelayWorker

    attr_accessor :broker, :pool, :queue, :handler

    def initialize(opts = {})
      @opts = Fluffy.config.merge(opts)
      @broker = @opts[:broker] || Fluffy::Broker.new(nil, @opts).tap{ |b| b.start }
      @pool = @opts[:worker_pool] || Concurrent::FixedThreadPool.new(@opts[:concurrency] || 1)
      @delay_name = "#{@opts[:exchange]}-delay"
    end

    def prepare
      @queue = broker.queue(@delay_name, @opts[:queue_options])

      @handler = broker.handler(@opts[:handler_class], @opts[:handler_options])
      # TODO use routing keys?
      @handler.bind_queue(@queue, @queue.name)
    end

    def run
      @consumer = queue.subscribe(:block => false, :manual_ack => @opts[:ack]) do | delivery_info, metadata, msg |
        pool.post do
          work(delivery_info, metadata, msg)
        end
      end
    end

    def start
      prepare
      run
    end

    def stop
      @consumer.cancel if @consumer
      @consumer = nil

      unless @opts[:worker_pool]
        @pool.shutdown
        @pool.wait_for_termination 12
      end
      broker.cleanup
      broker.stop
    end

    def work(delivery_info, metadata, msg)
      handler.handle(:ack, broker.channel, delivery_info, metadata, msg)
    end

    def logger
      Fluffy.logger
    end

  end
end
