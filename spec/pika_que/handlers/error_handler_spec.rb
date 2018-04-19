require 'spec_helper'

describe PikaQue::Handlers::ErrorHandler do
  let(:error_queue) { double('Bunny queue', name: 'dummy-error') }
  let(:error_exchange) { double('Bunny exchange') }
  let(:channel) { double('Bunny channel', closed?: false) }
  let(:conn) { instance_double(PikaQue::Connection, create_channel: channel) }
  let(:delivery_info) { double('delivery info', delivery_tag: 'tag', routing_key: 'tag')}
  let(:handler) { described_class.new(exchange: 'dummy-error', queue: 'dummy-error') }

  before do
    allow(PikaQue).to receive(:connection).and_return(conn)
    allow(channel).to receive(:exchange).with('dummy-error', type: :topic, durable: true).and_return(error_exchange)
    allow(channel).to receive(:queue).with('dummy-error', durable: true).and_return(error_queue)
    allow(error_queue).to receive(:bind).with(error_exchange, routing_key: '#')
  end

  describe '#initialize' do
    it 'should init with dummy exchange and queue' do
      expect(channel).to receive(:exchange).with('dummy-error', type: :topic, durable: true).and_return(error_exchange)
      expect(channel).to receive(:queue).with('dummy-error', durable: true).and_return(error_queue)
      expect(error_queue).to receive(:bind).with(error_exchange, routing_key: '#')
      described_class.new(exchange: 'dummy-error', queue: 'dummy-error')
    end
  end

  describe '#handle' do
    let(:main_channel) { double('Bunny channel', acknowledge: nil, reject: nil) }

    it 'should acknowledge with ack' do
      expect(main_channel).to receive(:acknowledge).with('tag', false)
      handler.handle(:ack, main_channel, delivery_info, {}, "msg")
    end

    it 'should requeue with reject' do
      expect(main_channel).to receive(:reject).with('tag', true)
      handler.handle(:requeue, main_channel, delivery_info, {}, "msg")
    end

    it 'should reject with reject' do
      expect(main_channel).to receive(:reject).with('tag', false)
      handler.handle(:reject, main_channel, delivery_info, {}, "msg")
    end

    it 'should publish to error queue with error' do
      expect(handler).to receive(:publish).with(delivery_info, "msg")
      expect(main_channel).to receive(:acknowledge).with('tag', false)
      handler.handle(:error, main_channel, delivery_info, {}, "msg", RuntimeError)
    end
  end

  describe '#close' do
    it 'should close channel' do
      expect(channel).to receive(:close)
      handler.close
    end
  end

  describe '#publish' do
    it 'should publish to error exchange' do
      expect(error_exchange).to receive(:publish).with("msg", routing_key: 'tag')
      handler.send :publish, delivery_info, "msg"
    end
  end

end
