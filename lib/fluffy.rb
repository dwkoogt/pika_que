require 'bunny'
require 'fluffy/configuration'
require 'fluffy/logging'
require 'fluffy/version'

require 'fluffy/connection'
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

end
