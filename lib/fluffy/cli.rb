require 'optparse'

require 'fluffy/connection'
require 'fluffy/launcher'
require 'fluffy/runner'

module Fluffy
  class CLI

    attr_accessor :environment

    def parse(args = ARGV)
      opts = parse_options(args)
      config.merge!(opts)
      init_logger
      daemonize
      write_pid
    end

    def run

      load_app

      Fluffy.middleware

      runner = Runner.new

      begin

        Launcher.launch(runner) do
          runner.run
        end

        exit 0
      rescue Interrupt
        Fluffy.logger.info 'Shutting down'
        runner.stop
        exit 1
      end
    end

    def config
      Fluffy.config
    end

    def init_logger
      Fluffy::Logging.init_logger(config[:logfile]) if config[:logfile]
      Fluffy.logger.level = ::Logger::WARN if config[:quite]
      Fluffy.logger.level = ::Logger::DEBUG if config[:verbose]
    end

    def daemonize
      return unless config[:daemon]

      files_to_reopen = []
      ObjectSpace.each_object(File) do |file|
        files_to_reopen << file unless file.closed?
      end

      ::Process.daemon(true, true)

      files_to_reopen.each do |file|
        begin
          file.reopen file.path, "a+"
          file.sync = true
        rescue ::Exception
        end
      end

      [$stdout, $stderr].each do |io|
        File.open(config[:logfile], 'ab') do |f|
          io.reopen(f)
        end
        io.sync = true
      end
      $stdin.reopen(File::NULL)

      init_logger
    end

    def write_pid
      if path = config[:pidfile]
        pidfile = File.expand_path(path)
        File.open(pidfile, 'w') do |f|
          f.puts ::Process.pid
        end
      end
    end

    def load_app
      if File.directory?(config[:require])
        rails_path = File.expand_path(File.join(config[:require], 'config', 'environment.rb'))
        if File.exist?(rails_path)
          ENV['RACK_ENV'] = ENV['RAILS_ENV'] = environment
          Fluffy.logger.info "found rails project (#{config[:require]}), booting app in #{ENV['RACK_ENV']} environment"
          require 'rails'
          require 'fluffy/rails'
          require rails_path
          ::Rails.application.eager_load!
        end
      else
        require(File.expand_path(config[:require])) || raise(ArgumentError, 'require returned false')
      end

      if config[:workers]
        config.add_processor({ workers: config.delete(:workers) })
      end

    end

    def parse_options(args)
      opts = {}

      @parser = OptionParser.new do |o|
        o.banner = 'usage: fluffy [options]'

        o.on '-c', '--concurrency INT', "processor threads to use" do |arg|
          opts[:concurrency] = Integer(arg)
        end

        o.on '-d', '--daemon', "Daemonize process" do |arg|
          opts[:daemon] = arg
        end

        o.on '-e', '--environment ENV', "Application environment" do |arg|
          opts[:environment] = arg
        end

        o.on '-q', '--quite', "Print quite output" do |arg|
          opts[:quite] = arg
        end

        o.on '-v', '--verbose', "Print verbose output" do |arg|
          opts[:verbose] = arg
        end

        o.on '-r', '--require [PATH|DIR]', "Location of Rails application with workers or file to require" do |arg|
          opts[:require] = arg
        end

        o.on '-w', '--worker WORKER(S)', "comma separated list of workers" do |arg|
          opts[:workers] = arg.split(",")
        end

        o.on '-L', '--logfile PATH', "path to writable logfile" do |arg|
          opts[:logfile] = arg
        end

        o.on '-P', '--pidfile PATH', "path to pidfile" do |arg|
          opts[:pidfile] = arg
        end

        o.on '-V', '--version', "Print version and exit" do
          puts "Fluffy #{Fluffy::VERSION}"
          exit 0
        end

        o.on_tail '-h', '--help', 'Show this message and exit' do
          puts o
          exit 0
        end
      end

      @parser.parse!(args)

      @environment = opts[:environment] || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'

      opts[:logfile] ||= opts[:daemon] ? 'fluffy.log' : STDOUT

      opts
    end
    
  end
end
