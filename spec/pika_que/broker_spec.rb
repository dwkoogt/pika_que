require 'spec_helper'

describe PikaQue::Broker do
  let(:queue) { double('Bunny queue') }
  let(:exchange) { double('Bunny exchange') }
  let(:channel) { double('Bunny channel', exchange: exchange, prefetch: nil, closed?: false, close: nil) }
  let(:conn) { instance_double(PikaQue::Connection, create_channel: channel, ensure_connection: nil, disconnect!: nil) }

  before do
    allow(PikaQue).to receive(:connection).and_return(conn)
    allow(PikaQue::Connection).to receive(:create).and_return(conn)
  end

  describe '#start' do
    context 'with defaults' do
      let(:broker) { described_class.new }

      it 'should ensure_connection' do
        expect(PikaQue).to receive(:connection)
        expect(conn).to receive(:ensure_connection)
        broker.start
      end
    end

    context 'with connection options' do
      let(:broker) { described_class.new(nil, connection_options: { amqp: 'amqp://dummy:dummy@localhost:5672/foobar', vhost: 'foobar' }) }

      it 'should ensure_connection' do
        expect(PikaQue).to_not receive(:connection)
        expect(PikaQue::Connection).to receive(:create).with({ amqp: 'amqp://dummy:dummy@localhost:5672/foobar', vhost: 'foobar' })
        expect(conn).to receive(:ensure_connection)
        broker.start
      end
    end
  end

  describe '#stop' do
    context 'with processor' do
      let(:processor) { double('Processor') }
      let(:broker) { described_class.new(processor) }

      it 'should pass thru' do
        broker.start
        expect(conn).to_not receive(:disconnect!)
        broker.stop
      end
    end

    context 'with local connection' do
      let(:broker) { described_class.new(nil, connection_options: {}) }

      it 'should pass thru' do
        broker.start
        expect(conn).to receive(:disconnect!)
        broker.stop
      end
    end

    context 'without processor' do
      let(:broker) { described_class.new }

      it 'should pass thru' do
        broker.start
        expect(conn).to receive(:disconnect!)
        broker.stop
      end
    end
  end

  describe '#channel' do
    let(:broker) { described_class.new }

    it 'should create channel' do
      broker.start
      expect(conn).to receive(:create_channel)
      broker.channel
    end

    it 'should return a channel' do
      broker.start
      expect(broker.channel).to eq channel
    end
  end

  describe '#exchange' do
    let(:broker) { described_class.new }

    it 'should create exchange' do
      broker.start
      expect(channel).to receive(:exchange)
      broker.exchange
    end

    it 'should return a exchange' do
      broker.start
      expect(broker.exchange).to eq exchange
    end
  end

  describe '#queue' do
    let(:broker) { described_class.new }

    it 'should create queue and bind to exchange' do
      broker.start
      expect(channel).to receive(:queue).with('foo', {}).and_return(queue)
      expect(queue).to receive(:bind).with(exchange, { routing_key: 'foo' })
      expect(broker.queue('foo', {})).to eq queue
    end

    it 'should create queue and bind to exchange with a routing_key' do
      broker.start
      expect(channel).to receive(:queue).with('foo', { routing_key: 'bar' }).and_return(queue)
      expect(queue).to receive(:bind).with(exchange, { routing_key: 'bar' })
      expect(broker.queue('foo', { routing_key: 'bar' })).to eq queue
    end

    context 'failure' do
      before do 
        allow(channel).to receive(:queue).and_raise("Boom!")
        allow(PikaQue.logger).to receive(:fatal)
      end

      it 'should raise SetupError on exception' do
        broker.start
        expect{ broker.queue('foo', {}) }.to raise_error(PikaQue::SetupError, "Boom!")
      end
    end
  end

  describe '#default_handler' do
    context 'with defaults' do
      let(:broker) { described_class.new }

      it 'should return default handler' do
        expect(broker.default_handler).to be_instance_of(PikaQue::Handlers::DefaultHandler)
      end
    end

    context 'with configured handler' do
      let(:broker) { described_class.new(nil, handler_class: PikaQue::Handlers::ErrorHandler, handler_options: {}) }
      let(:err_handler) { instance_double(PikaQue::Handlers::ErrorHandler) }
      before { allow(PikaQue::Handlers::ErrorHandler).to receive(:new).and_return(err_handler) }

      it 'should return error handler' do
        expect(broker.default_handler).to eq err_handler
      end
    end
  end

  describe '#handler' do
    context 'with defaults' do
      let(:broker) { described_class.new }

      it 'should return default handler' do
        expect(broker.handler(nil)).to be_instance_of(PikaQue::Handlers::DefaultHandler)
      end
    end

    context 'with configured handler' do
      let(:broker) { described_class.new(nil, handler_class: PikaQue::Handlers::ErrorHandler, handler_options: {}) }
      let(:err_handler) { instance_double(PikaQue::Handlers::ErrorHandler) }
      before { allow(PikaQue::Handlers::ErrorHandler).to receive(:new).and_return(err_handler) }

      it 'should return error handler as default' do
        expect(broker.handler(nil)).to eq err_handler
      end
    end

    context 'with handler args' do
      let(:broker) { described_class.new }
      let(:err_handler) { instance_double(PikaQue::Handlers::ErrorHandler) }
      before { allow(PikaQue::Handlers::ErrorHandler).to receive(:new).and_return(err_handler) }

      it 'should return error handler' do
        expect(broker.handler(PikaQue::Handlers::ErrorHandler)).to eq err_handler
      end
    end
  end

  describe '#cleanup' do
    let(:default_handler) { instance_double(PikaQue::Handlers::DefaultHandler) }
    before { allow(PikaQue::Handlers::DefaultHandler).to receive(:new).and_return(default_handler) }
    let(:err_handler) { instance_double(PikaQue::Handlers::ErrorHandler) }
    before { allow(PikaQue::Handlers::ErrorHandler).to receive(:new).and_return(err_handler) }

    context 'with defaults' do
      let(:broker) { described_class.new }

      it 'should close channel and default_handler' do
        broker.start
        broker.channel
        broker.default_handler
        expect(channel).to receive(:close)
        expect(default_handler).to receive(:close)
        broker.cleanup
      end

      it 'should close additional handlers' do
        broker.start
        broker.channel
        broker.handler(PikaQue::Handlers::ErrorHandler)
        expect(err_handler).to receive(:close)
        broker.cleanup
      end
    end

    context 'with processor' do
      let(:processor) { double('Processor') }
      let(:broker) { described_class.new(processor) }

      it 'should not call close on anything' do
        broker.start
        broker.channel
        broker.default_handler
        broker.handler(PikaQue::Handlers::ErrorHandler)
        expect(channel).to_not receive(:close)
        expect(default_handler).to_not receive(:close)
        expect(err_handler).to_not receive(:close)
        broker.cleanup
      end

      it 'should call close on all with force' do
        broker.start
        broker.channel
        broker.default_handler
        broker.handler(PikaQue::Handlers::ErrorHandler)
        expect(channel).to receive(:close)
        expect(default_handler).to receive(:close)
        expect(err_handler).to receive(:close)
        broker.cleanup(true)
      end
    end
  end
end
