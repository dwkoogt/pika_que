module PikaQue
  class Connection
    extend Forwardable

    def_delegators :@connection, :create_channel

    include Logging

    attr_reader :connection

    def initialize(opts = {})
      @opts = PikaQue.config.merge(opts)
      @opts[:amqp]  = ENV.fetch('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672')
      @opts[:vhost] = AMQ::Settings.parse_amqp_url(@opts[:amqp]).fetch(:vhost, '/')
    end

    def self.create(opts = {})
      new(opts).tap{ |conn| conn.connect! }
    end

    def connect!
      @connection ||= Bunny.new(@opts[:amqp], :vhost => @opts[:vhost],
                              :heartbeat => @opts[:heartbeat],
                              :properties => @opts.fetch(:properties, {}),
                              :logger => PikaQue::logger).tap do |conn|
        conn.start
      end
    end

    def connected?
      @connection && @connection.connected?
    end

    def disconnect!
      @connection.close if @connection
      @connection = nil
    end

    def ensure_connection
      unless connected?
        @connection = nil
        connect!
      end
    end
    
  end
end
