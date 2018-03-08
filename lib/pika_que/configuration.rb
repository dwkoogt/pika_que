require 'forwardable'

require 'pika_que/codecs/json'
require 'pika_que/codecs/noop'

require 'pika_que/processor'
require 'pika_que/handlers/default_handler'

require 'pika_que/delay_worker'
require 'pika_que/handlers/delay_handler'

module PikaQue
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

    DELAY_PROCESSOR_DEFAULTS = {
      :workers            => [PikaQue::DelayWorker],
      :handler_class      => PikaQue::Handlers::DelayHandler,
      :concurrency        => 1
    }.freeze
  
    DEFAULT_CONFIG = {
      :exchange           => 'pika-que',
      :heartbeat          => 30,
      :channel_options    => CHANNEL_OPTION_DEFAULTS,
      :exchange_options   => EXCHANGE_OPTION_DEFAULTS,
      :queue_options      => QUEUE_OPTION_DEFAULTS,
      :concurrency        => 1,
      :ack                => true,
      :handler_class      => PikaQue::Handlers::DefaultHandler,
      :handler_options    => {},
      :codec              => PikaQue::Codecs::JSON,
      :processors         => [],
      :reporters          => [],
      :metrics            => nil,
      :delay              => true,
      :delay_options      => DELAY_PROCESSOR_DEFAULTS,
      :pidfile            => nil,
      :require            => '.'
    }.freeze

    # processor example
    # @processor            Processor class
    # @workers              array of worker classes
    # @connection           connection params if using separate connection
    # {
    #   :processor          => Processor,
    #   :connection_options => {},
    #   :workers            => [],
    #   :concurrency        => 1,
    #   :ack                => true,
    #   :handler_class      => nil,
    #   :handler_options    => nil,
    #   :codec              => PikaQue::Codecs::JSON
    # }

    def initialize
      @config = DEFAULT_CONFIG.dup
      @config[:amqp]  = ENV.fetch('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672')
      @config[:vhost] = AMQ::Settings.parse_amqp_url(@config[:amqp]).fetch(:vhost, '/')
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

    def processor(opts = {})
      {
        :processor        => PikaQue::Processor,
        :workers          => []
      }.merge(opts)
    end

    def add_processor(opts = {})
      @config[:processors] << processor(opts)
    end

  end
end
