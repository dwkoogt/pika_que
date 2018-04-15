module PikaQue
  class Runner

    def run
      # TODO anything to add to run_config?
      run_config = {}

      @processes = []
      processors.each do |processor_hash|
        _processor = PikaQue::Util.constantize(processor_hash[:processor]).new(processor_hash.merge(run_config))
        _processor.start
        @processes << _processor
      end
    end

    # halt? pause?
    def stop
      @processes.each(&:stop)
      PikaQue.connection.disconnect!
    end

    def setup_processors
      add_processor(config[:delay_options]) if config[:delay]
      if config[:workers]
        add_processor({ workers: config[:workers] })
      else
        config[:processors].each{ |p| add_processor(p) }
      end
    end

    def processor(opts = {})
      {
        :processor        => PikaQue::Processor,
        :workers          => []
      }.merge(opts)
    end

    def add_processor(opts = {})
      classified_workers = { :workers => PikaQue::Util.worker_classes(opts[:workers]) }
      processors << processor(opts.merge(classified_workers))
    end

    def processors
      @processors ||= []
    end

    def config
      PikaQue.config
    end

  end
end
