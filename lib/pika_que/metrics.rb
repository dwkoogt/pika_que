require 'pika_que/metrics/log_metric'
require 'pika_que/metrics/null_metric'

module PikaQue
  module Metrics

    def self.metrics
      @metrics || init_metrics
    end

    def self.init_metrics
      if PikaQue.config[:metrics]
        @metrics = PikaQue.config[:metrics].new
      elsif PikaQue.config[:quite]
        @metrics = PikaQue::Metrics::NullMetric.new
      else
        @metrics = PikaQue::Metrics::LogMetric.new
      end
    end

    def metrics
      PikaQue::Metrics.metrics
    end

  end
end
