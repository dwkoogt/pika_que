require 'logger'
require 'time'

module PikaQue
  module Logging

    class PikaQueFormatter < Logger::Formatter
      def call(severity, time, program_name, message)
        "#{time.utc.iso8601} #{Process.pid} T-#{Thread.current.object_id.to_s(36)} #{severity}: #{message}\n"
      end
    end

    def self.init_logger(stream = STDOUT)
      @logger = Logger.new(stream, 5, 1048576).tap do |l|
        l.level = Logger::INFO
        l.formatter = PikaQueFormatter.new
      end
    end

    def self.logger
      @logger || init_logger
    end

    def self.logger=(logger)
      @logger = logger ? logger : Logger.new(File::NULL)
    end

    def logger
      PikaQue::Logging.logger
    end

  end
end
