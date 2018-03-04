require 'pika_que/worker'
require 'pika_que/codecs/rails'

module PikaQue
  class Rails < ::Rails::Engine

    config.before_configuration do
      if ::Rails::VERSION::MAJOR < 5 && defined?(::ActiveRecord)
        PikaQue.middleware do |chain|
          require 'pika_que/middleware/active_record'
          chain.add PikaQue::Middleware::ActiveRecord
        end
      end
    end

    config.before_initialize do
      require 'active_job/queue_adapters/pika_que_adapter'
    end

    config.after_initialize do
      config_file = ::Rails.root.join('config').join('pika_que.yml')
      if File.exist? config_file
        PIKA_QUE_CONFIG = YAML.load_file(config_file)
      else
        mailer_queue = (::Rails::VERSION::MAJOR < 5) ? ActionMailer::DeliveryJob.queue_name : ActionMailer::Base.deliver_later_queue_name
        PIKA_QUE_CONFIG = { "processors" => [{ "workers" => [{ "queue" => ActiveJob::Base.queue_name }, { "queue" => mailer_queue.to_s }] }] }
      end

      workers_dir = ::Rails.root.join('app').join('workers')
      if Dir.exist? workers_dir
        worker_files = Dir.glob(workers_dir.join('*.rb'))
      else
        worker_files = []
      end

      # TODO options, etc

      PIKA_QUE_CONFIG['processors'].each do |processor|
        workers = []
        processor['workers'].each do |worker|
          queue = worker['queue']
          worker_name = worker['worker'] || "#{queue.underscore.classify}Worker"
          Object.const_set(worker_name, Class.new do
              include PikaQue::Worker
              from_queue queue
              config codec: PikaQue::Codecs::RAILS

              def perform(msg)
                ActiveJob::Base.execute msg
                ack!
              end
            end
          ) unless worker_files.detect{ |w| w =~ /#{worker_name.underscore}/ }
          workers << worker_name
        end
        proc_args = { workers: workers }
        proc_args[:processor] = processor['processor'] if processor['processor']
        PikaQue.config.add_processor(proc_args)
      end
    end

  end
end
