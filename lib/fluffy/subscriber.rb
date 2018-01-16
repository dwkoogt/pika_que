module Fluffy
  class Subscriber
    include Logging

    attr_accessor :broker, :pool, :queue, :handler

    def initialize(opts = {})
      @opts = Fluffy.config.merge(opts)
      @codec = @opts[:codec]
      @broker = @opts[:broker] || Fluffy::Broker.new(nil, @opts).tap{ |b| b.start }
      @pool = @opts[:worker_pool] || Concurrent::FixedThreadPool.new(@opts[:concurrency] || 1)
    end

    def setup_queue(queue_name, queue_opts)
      @queue = broker.queue(queue_name, @opts[:queue_options].merge(queue_opts))
    end

    def setup_handler(handler_class, handler_opts)
      @handler = broker.handler(handler_class, handler_opts)
    end

    def subscribe(worker)
      @consumer = queue.subscribe(:block => false, :manual_ack => @opts[:ack], :arguments => worker.consumer_arguments) do | delivery_info, metadata, msg |
        # TODO make idletime configurable on thread pool? default is 60.
        pool.post do
          res = nil
          error = nil
          begin
            decoded_msg = @codec.decode(msg)
            Fluffy.middleware.invoke(self, delivery_info, metadata, decoded_msg) do
              res = worker.work(delivery_info, metadata, decoded_msg)
            end
            logger.info "done processing #{res} <#{msg}>"
          rescue => e
            res = :error
            error = e
            logger.info "error processing <#{msg}>"
            logger.error e
            logger.error e.backtrace.join("\n") unless e.backtrace.nil?
          end

          handler.handle(res, queue.channel, delivery_info, metadata, msg, error) if @opts[:ack]
        end
      end
    end

    def unsubscribe
      @consumer.cancel if @consumer
      @consumer = nil
    end

    def teardown
      unless @opts[:worker_pool]
        @pool.shutdown
        @pool.wait_for_termination 12
      end
      broker.cleanup
      broker.stop
    end

  end
end
