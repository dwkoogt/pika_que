require 'pika_que/subscriber'

module PikaQue
  module Worker

    def initialize(opts = {})
      @subscriber = PikaQue::Subscriber.new(opts.merge(self.class.local_config || {}))
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
      PikaQue.logger
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
      attr_reader :local_config

      def from_queue(q, opts={})
        @queue_name = q.to_s
        @priority = opts.delete(:priority)
        @queue_opts = opts
      end

      def handle_with(handler, opts={})
        @handler_class = handler
        @handler_opts = opts
      end

      def enqueue(msg, opts={})
        opts[:routing_key] ||= (queue_opts[:routing_key] if queue_opts)
        opts[:to_queue] ||= queue_name
        opts[:priority] ||= priority

        publisher.publish(msg, opts)
      end
      alias_method :perform_async, :enqueue

      def enqueue_at(msg, timestamp, opts={})
        opts[:to_queue] ||= "#{PikaQue.config[:exchange]}-delay"
        work_queue = opts.delete(:routing_key) || (queue_opts[:routing_key] if queue_opts) || queue_name
        opts[:headers] = { work_at: timestamp, work_queue: work_queue }

        publisher.publish(msg, opts)
      end
      alias_method :perform_at, :enqueue

      def config(opts)
        @local_config = opts
      end

      private

      def publisher
        @publisher ||= PikaQue::Publisher.new(local_config || {})
      end

    end
  
  end
end
