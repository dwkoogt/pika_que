module PikaQue
  module Reporters

    def notify_reporters(ex, clazz, msg)
      PikaQue.reporters.each do |reporter|
        begin
          reporter.report(ex, clazz, msg)
        rescue => e
          PikaQue.logger.error "error reporting by #{reporter.class}"
          PikaQue.logger.error e
          PikaQue.logger.error e.backtrace.join("\n") unless e.backtrace.nil?
        end
        
      end
    end
    
  end
end
