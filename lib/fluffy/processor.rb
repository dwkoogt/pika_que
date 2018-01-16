require 'fluffy/broker'
require 'fluffy/logging'
require 'fluffy/util'

module Fluffy
  class Processor
    include Logging

    def initialize(opts = {})
      @opts = Fluffy.config.merge(opts)
      @broker = Fluffy::Broker.new(self, @opts).tap{ |b| b.start }
      @pool = Concurrent::FixedThreadPool.new(@opts[:concurrency] || 1)
      proc_config = @opts.merge({ broker: @broker, worker_pool: @pool })
      @workers = @opts.fetch(:workers, []).map{ |w| Fluffy::Util.constantize(w).new(proc_config) }
      @thread = nil
    end

    def process
      @workers.each do |worker|
        worker.start
      end
    end

    def start
      @thread = Thread.new do
        Thread.current['label'] = 'processor'
        process
      end
    end

    def stop
      @workers.each(&:stop)

      @pool.shutdown
      @pool.wait_for_termination 12

      @broker.cleanup(true)
      @broker.stop
    end

  end
end
