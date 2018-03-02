module PikaQue
  module Reporters
    class LogReporter

      def report(ex, clazz, msg)
        PikaQue.logger.debug "error processing <#{msg}>"
        PikaQue.logger.error "Exception #{ex.class} in #{clazz}: #{ex.message}" unless ex.nil?
        PikaQue.logger.error ex.backtrace.join("\n") unless ex.nil? || ex.backtrace.nil?
      end

    end
  end
end
