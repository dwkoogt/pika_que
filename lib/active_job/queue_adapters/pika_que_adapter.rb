require 'pika_que/rails_worker'
require 'thread'

module ActiveJob
  module QueueAdapters
    # == PikaQue adapter for Active Job
    #
    # PikaQue is a RabbitMQ background processing framework for Ruby.
    #
    # Read more about PikaQue {here}[https://github.com/dwkoogt/pika_que].
    #
    # To use PikaQue set the queue_adapter config to +:pika_que+.
    #
    #   Rails.application.config.active_job.queue_adapter = :pika_que
    #
    class PikaQueRails4
      @monitor = Monitor.new

      class << self
        def enqueue(job) #:nodoc:
          @monitor.synchronize do
            PikaQue::RailsWorker.enqueue job.serialize, to_queue: job.queue_name
          end
        end

        def enqueue_at(job, timestamp) #:nodoc:
          @monitor.synchronize do
            PikaQue::RailsWorker.enqueue_at job.serialize, timestamp, routing_key: job.queue_name
          end
        end
      end
    end

    class PikaQueRails5
      def initialize
        @monitor = Monitor.new
      end

      def enqueue(job) #:nodoc:
        @monitor.synchronize do
          PikaQue::RailsWorker.enqueue job.serialize, to_queue: job.queue_name, priority: job.priority
        end
      end

      def enqueue_at(job, timestamp) #:nodoc:
        @monitor.synchronize do
          PikaQue::RailsWorker.enqueue_at job.serialize, timestamp, routing_key: job.queue_name
        end
      end
    end

    PikaQueAdapter = (::Rails::VERSION::MAJOR < 5) ? PikaQueRails4 : PikaQueRails5

  end
end
