module PikaQue
  class Runner

    def run
      run_config = {}

      # TODO anything to add to run_config?

      @processors = []
      PikaQue.config[:processors].each do |processor_hash|
        _processor = PikaQue::Util.constantize(processor_hash[:processor]).new(processor_hash.merge(run_config))
        _processor.start
        @processors << _processor
      end
    end

    # halt? pause?
    def stop
      @processors.each(&:stop)
      PikaQue.connection.disconnect!
    end

  end
end
