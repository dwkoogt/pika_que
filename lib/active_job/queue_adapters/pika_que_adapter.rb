require 'pika_que'
require 'pika_que/codecs/rails'
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
    class PikaQueAdapter
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
        extend PikaQue::Worker::ClassMethods
        config codec: PikaQue::Codecs::RAILS
      end
    end

    autoload :PikaQueAdapter
  end
end
