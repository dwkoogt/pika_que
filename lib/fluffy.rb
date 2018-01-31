require 'bunny'
require 'concurrent/executors'

require 'fluffy/configuration'
require 'fluffy/logging'
require 'fluffy/version'

require 'fluffy/connection'
require 'fluffy/publisher'
require 'fluffy/middleware/chain'
require 'fluffy/worker'

module Fluffy

  def self.config
    @config ||= Configuration.new
  end

  def self.logger
    Fluffy::Logging.logger
  end

  def self.logger=(logger)
    Fluffy::Logging.logger = logger
  end

  def self.connection
    @connection ||= Connection.create
  end

  def self.middleware
    @chain ||= Middleware::Chain.new
    yield @chain if block_given?
    @chain
  end

end
