require 'concurrent/map'

module Fluffy
  module Metrics
    class LogMetric

      COUNTERS = Concurrent::Map.new

      def increment(metric, delta = 1)
        COUNTERS[metric] = 0 unless COUNTERS[metric]
        COUNTERS[metric] = COUNTERS[metric] + delta
        Fluffy.logger.info("COUNT: #{metric} #{COUNTERS[metric]}")
      end

      def measure(metric)
        start = Time.now
        yield
        Fluffy.logger.info("TIME: #{metric} #{Time.now - start}")
      end

    end
  end
end
