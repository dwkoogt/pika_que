require 'pika_que/reporters'
require 'pika_que/metrics'

module PikaQue
  class Subscriber
    include Logging
    include Reporters
    include Metrics

    attr_accessor :broker, :pool, :queue, :handler

    def initialize(opts = {})
      @opts = PikaQue.config.merge(opts)
      @codec = @opts[:codec]
      @broker = @opts[:broker] || PikaQue::Broker.new(nil, @opts).tap{ |b| b.start }
      @pool = @opts[:worker_pool] || Concurrent::FixedThreadPool.new(@opts[:concurrency] || 1)
    end

    def setup_queue(queue_name, queue_opts)
      @queue = broker.queue(queue_name, @opts[:queue_options].merge(queue_opts))
    end

    def setup_handler(handler_class, handler_opts)
      @handler = broker.handler(handler_class, @opts[:handler_options].merge(handler_opts || {}))
      # TODO use routing keys?
      logger.info "binding queue #{@queue.name} to handler #{@handler.class}"
      @handler.bind_queue(@queue, @queue.name)
    end

    def subscribe(worker)
      @consumer = queue.subscribe(:block => false, :manual_ack => @opts[:ack], :arguments => worker.consumer_arguments) do | delivery_info, metadata, msg |
        # TODO make idletime configurable on thread pool? default is 60.
        pool.post do
          res = nil
          error = nil
          begin
            decoded_msg = @codec.decode(msg)
            metrics.measure("work.#{self.class.name}.time") do
              PikaQue.middleware.invoke(self, delivery_info, metadata, decoded_msg) do
                res = worker.work(delivery_info, metadata, decoded_msg)
              end
            end
            logger.debug "done processing #{res} <#{msg}>"
          rescue => worker_err
            res = :error
            error = worker_err
            notify_reporters(worker_err, worker.class, msg)
          end

          if @opts[:ack]
            begin
              handler.handle(res, broker.channel, delivery_info, metadata, msg, error)
              metrics.increment("work.#{self.class.name}.handled.#{res}") 
            rescue => handler_err
              notify_reporters(handler_err, handler.class, msg)
              metrics.increment("work.#{self.class.name}.handler.error") 
            end
          else
            metrics.increment("work.#{self.class.name}.handled.noop") 
          end
          metrics.increment("work.#{self.class.name}.processed")
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
