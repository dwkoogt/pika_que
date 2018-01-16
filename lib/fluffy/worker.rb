require 'fluffy/subscriber'

module Fluffy
  module Worker

    def initialize(opts = {})
      @subscriber = Fluffy::Subscriber.new(opts)
    end

    def prepare
      @subscriber.setup_queue(self.class.queue_name, self.class.queue_opts)
      @subscriber.setup_handler(self.class.handler_class, self.class.handler_opts)
    end

    def run
      @subscriber.subscribe(self)
    end

    def start
      prepare
      run
    end

    def stop
      @subscriber.unsubscribe
      @subscriber.teardown
    end

    def work(delivery_info, metadata, msg)
      perform(msg)
    end

    def ack!; :ack end
    def reject!; :reject; end
    def requeue!; :requeue; end

    def logger
      Fluffy.logger
    end

    def consumer_arguments
      self.class.priority.nil? ? {} : { :'x-priority' => self.class.priority }
    end

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      attr_reader :queue_name
      attr_reader :queue_opts
      attr_reader :handler_class
      attr_reader :handler_opts
      attr_reader :priority

      def from_queue(q, opts={})
        @queue_name = q.to_s
        @priority = opts.delete(:priority)
        @queue_opts = Fluffy.config[:queue_options].merge(opts)
      end

      def handle_with(handler, opts={})
        @handler_class = handler
        @handler_opts = Fluffy.config[:handler_options].merge(opts)
      end

      def enqueue(msg, opts={})
        opts[:routing_key] ||= queue_opts[:routing_key]
        opts[:to_queue] ||= queue_name
        opts[:priority] ||= priority

        publisher.publish(msg, opts)
      end
      alias_method :perform_async, :enqueue

      def enqueue_at(msg, timestamp, opts={})
        opts[:routing_key] ||= queue_opts[:routing_key]
        opts[:to_queue] ||= 'fluffy-delay'
        opts[:headers] = { work_at: timestamp, work_queue: @queue_name }

        publisher.publish(msg, opts)
      end
      alias_method :perform_at, :enqueue

      private

      def publisher
        @publisher ||= Fluffy::Publisher.new(queue_opts)
      end

    end
  
  end
end
