require 'concurrent/map'

module PikaQue
  module Metrics
    class LogMetric

      COUNTERS = Concurrent::Map.new

      def increment(metric, delta = 1)
        COUNTERS[metric] = 0 unless COUNTERS[metric]
        COUNTERS[metric] = COUNTERS[metric] + delta
        PikaQue.logger.info("COUNT: #{metric} #{COUNTERS[metric]}")
      end

      def measure(metric, &block)
        start = Time.now
        block.call
        PikaQue.logger.info("TIME: #{metric} #{Time.now - start}")
      end

    end
  end
end
