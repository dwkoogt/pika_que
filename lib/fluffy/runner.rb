module Fluffy
  class Runner

    def run
      run_config = {}

      # TODO anything to add to run_config?

      @processors = []
      Fluffy.config[:processors].each do |processor_hash|
        _processor = Fluffy::Util.constantize(processor_hash[:processor]).new(processor_hash.merge(run_config))
        _processor.start
        @processors << _processor
      end
    end

    # halt? pause?
    def stop
      @processors.each(&:stop)
      Fluffy.connection.disconnect!
    end

  end
end
