module Fluffy
  module Metrics
    class NullMetric

      def increment(metric, delta = 1)
      end

      def measure(metric, &block)
        block.call
      end

    end
  end
end
