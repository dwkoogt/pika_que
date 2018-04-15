require 'pika_que/rails_worker'
require 'pika_que/util'

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
        PIKA_QUE_CONFIG = YAML.load_file(config_file).deep_symbolize_keys
      else
        mailer_queue = (::Rails::VERSION::MAJOR < 5) ? ActionMailer::DeliveryJob.queue_name : ActionMailer::Base.deliver_later_queue_name
        PIKA_QUE_CONFIG = { processors: [{ workers: [{ queue: ActiveJob::Base.queue_name }, { queue: mailer_queue.to_s }] }] }
      end

      workers_dir = ::Rails.root.join('app').join('workers')
      if Dir.exist? workers_dir
        worker_files = Dir.glob(workers_dir.join('*.rb'))
      else
        worker_files = []
      end

      PIKA_QUE_CONFIG[:processors].each do |processor|
        workers = []
        processor[:workers].each do |worker|
          if worker[:worker]
            worker_name = worker[:worker]
          else
            queue_name = worker[:queue_name] || worker[:queue]
            queue_opts = worker[:queue_opts] || {}
            worker_name = "#{queue_name.underscore.classify}Worker"
            unless worker_files.detect{ |w| w =~ /#{worker_name.underscore}/ }
              PikaQue::Util.register_worker_class(worker_name, PikaQue::RailsWorker, queue_name)
            end
          end
          workers << worker_name
        end
        processor[:workers] = workers
        unless PikaQue.config[:workers] || PikaQue.config[:config]
          PikaQue.logger.info "Adding rails processor: #{processor}"
          PikaQue.config[:processors] << processor
        end
      end
    end

  end
end
