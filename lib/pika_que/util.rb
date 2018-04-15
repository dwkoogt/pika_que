require "dry/inflector"

module PikaQue
  module Util
    extend self
    
    def constantize(str)
      return str if (str.is_a?(Class) || str.is_a?(Module))

      names = str.split('::')
      names.shift if names.empty? || names.first.empty?

      names.inject(Object) do |constant, name|
        constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
      end
    end

    def register_worker_class(worker_name, base_class, queue_name, queue_opts = {}, handler_class = nil, handler_opts = {}, local_config = {})
      Object.const_set(worker_name, Class.new(base_class) do
          from_queue queue_name, queue_opts         
          handle_with handler_class, handler_opts if handler_class
          config local_config if local_config.any?
        end
      )
    end

    def worker_classes(workers = [])
      return [] if workers.nil?
      
      workers.map do |worker|
        if worker.is_a? Hash
          if worker[:worker]
            worker[:worker]
          else
            queue_name = worker[:queue_name] || worker[:queue]
            "#{inflector.classify(inflector.underscore(queue_name))}Worker"
          end
        else
          worker
        end
      end
    end

    def inflector
      @inflector ||= Dry::Inflector.new
    end

  end
end
