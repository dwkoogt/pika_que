require 'fluffy/metrics/log_metric'
require 'fluffy/metrics/null_metric'

module Fluffy
  module Metrics

    def self.metrics
      @metrics || init_metrics
    end

    def self.init_metrics
      if Fluffy.config[:metrics]
        @metrics = Fluffy.config[:metrics].new
      elsif Fluffy.config[:quite]
        @metrics = Fluffy::Metrics::NullMetric.new
      else
        @metrics = Fluffy::Metrics::LogMetric.new
      end
    end

    def metrics
      Fluffy::Metrics.metrics
    end

  end
end
