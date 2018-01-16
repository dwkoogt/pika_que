require 'forwardable'

module Fluffy
  class Configuration
    extend Forwardable

    def_delegators :@config, :to_hash, :[], :[]=, :==, :fetch, :delete, :has_key?

    EXCHANGE_OPTION_DEFAULTS = {
      :type               => :direct,
      :durable            => true,
      :auto_delete        => false,
      :arguments => {} # Passed as :arguments to Bunny::Channel#exchange
    }.freeze

    QUEUE_OPTION_DEFAULTS = {
      :durable            => true,
      :auto_delete        => false,
      :exclusive          => false,
      :arguments => {}
    }.freeze

    CHANNEL_OPTION_DEFAULTS = {
      :consumer_pool_size => 1,
      :prefetch           => 10
    }.freeze
  
    DEFAULT_CONFIG = {
      :exchange           => 'fluffy',
      :heartbeat          => 30,
      :channel_options    => CHANNEL_OPTION_DEFAULTS,
      :exchange_options   => EXCHANGE_OPTION_DEFAULTS,
      :queue_options      => QUEUE_OPTION_DEFAULTS,
      :concurrency        => 1,
      :ack                => true,
      :pidfile            => nil,
      :require            => '.'
    }

    def initialize
      @config = DEFAULT_CONFIG.dup
    end

    def merge!(other = {})
      @config = deep_merge(@config, other)
    end

    def merge(other = {})
      instance = self.class.new
      instance.merge! to_hash
      instance.merge! other
      instance
    end

    def deep_merge(first, second)
      merger = proc { |_, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
      first.merge(second, &merger)
    end

  end
end
