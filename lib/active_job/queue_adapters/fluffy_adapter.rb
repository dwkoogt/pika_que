require 'fluffy'
require 'fluffy/codecs/rails'
require 'thread'

module ActiveJob
  module QueueAdapters
    # == Fluffy adapter for Active Job
    #
    # Fluffy is a RabbitMQ background processing framework for Ruby.
    #
    # Read more about Fluffy {here}[https://github.com/dwkoogt/fluffy].
    #
    # To use Fluffy set the queue_adapter config to +:fluffy+.
    #
    #   Rails.application.config.active_job.queue_adapter = :fluffy
    #
    class FluffyAdapter
      @monitor = Monitor.new

      class << self
        def enqueue(job) #:nodoc:
          @monitor.synchronize do
            JobWrapper.enqueue job.serialize, to_queue: job.queue_name
          end
        end

        def enqueue_at(job, timestamp) #:nodoc:
          @monitor.synchronize do
            JobWrapper.enqueue_at job.serialize, timestamp, routing_key: job.queue_name
          end
        end
      end

      class JobWrapper #:nodoc:
        extend Fluffy::Worker::ClassMethods
        config codec: Fluffy::Codecs::RAILS
      end
    end

    autoload :FluffyAdapter
  end
end
