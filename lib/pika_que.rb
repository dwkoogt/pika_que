require 'bunny'
require 'concurrent/executors'

require 'pika_que/configuration'
require 'pika_que/errors'
require 'pika_que/logging'
require 'pika_que/version'

require 'pika_que/connection'
require 'pika_que/publisher'
require 'pika_que/reporters/log_reporter'
require 'pika_que/middleware/chain'
require 'pika_que/handlers'
require 'pika_que/worker'

module PikaQue

  def self.config
    @config ||= Configuration.new
  end

  def self.configure(opts = {})
    config.merge!(opts)
  end

  def self.logger
    PikaQue::Logging.logger
  end

  def self.logger=(logger)
    PikaQue::Logging.logger = logger
  end

  def self.connection
    @connection ||= Connection.create
  end

  def self.middleware
    @chain ||= Middleware::Chain.new
    yield @chain if block_given?
    @chain
  end

  def self.reporters
    @reporters ||= [PikaQue::Reporters::LogReporter.new]
    yield @reporters if block_given?
    @reporters
  end

  def self.reset!
    @config = nil
    @connection = nil
    @chain = nil
    @reporters = nil
  end

end

require 'pika_que/rails' if defined?(::Rails::Engine)
