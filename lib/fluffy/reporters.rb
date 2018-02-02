module Fluffy
  module Reporters

    def notify_reporters(ex, clazz, msg)
      Fluffy.reporters.each do |reporter|
        begin
          reporter.report(ex, clazz, msg)
        rescue => e
          Fluffy.logger.error "error reporting by #{reporter.class}"
          Fluffy.logger.error e
          Fluffy.logger.error e.backtrace.join("\n") unless e.backtrace.nil?
        end
        
      end
    end
    
  end
end
