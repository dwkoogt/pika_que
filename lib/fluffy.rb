require 'fluffy/configuration'
require 'fluffy/logging'
require 'fluffy/version'

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

end
