module Fluffy
  module Reporters
    class LogReporter

      def report(ex, clazz, msg)
        Fluffy.logger.debug "error processing <#{msg}>"
        Fluffy.logger.error "Exception #{ex.class} in #{clazz}: #{ex.message}" unless ex.nil?
        Fluffy.logger.error ex.backtrace.join("\n") unless ex.nil? || ex.backtrace.nil?
      end

    end
  end
end
