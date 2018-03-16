require 'spec_helper'

describe PikaQue::Publisher do
  let(:exchange) { double('Bunny exchange') }
  let(:channel) { double('Bunny channel', exchange: exchange) }
  let(:conn) { instance_double(PikaQue::Connection, create_channel: channel) }

  before do
    allow(PikaQue).to receive(:connection).and_return(conn)
  end

  describe '#initialize' do
    context 'with defaults' do
      let(:publisher) { described_class.new }

      it 'should have defaults' do
        expect(PikaQue).to receive(:connection)
        expect(publisher.instance_variable_get(:@codec)).to_not be_nil
        expect(publisher.instance_variable_get(:@connection)).to eq conn
        expect(publisher.instance_variable_get(:@channel)).to eq channel
        expect(publisher.instance_variable_get(:@exchange)).to eq exchange
      end
    end

    context 'with passed in connection' do
      let(:publisher) { described_class.new(connection: conn) }

      it 'should have defaults' do
        expect(PikaQue).to_not receive(:connection)
        expect(publisher.instance_variable_get(:@codec)).to_not be_nil
        expect(publisher.instance_variable_get(:@connection)).to eq conn
        expect(publisher.instance_variable_get(:@channel)).to eq channel
        expect(publisher.instance_variable_get(:@exchange)).to eq exchange
      end
    end
  end

  describe '#publish' do
    let(:publisher) { described_class.new }
    let(:codec) { double('Codec', content_type: 'application/json') }
    let(:msg) { "hello world!" }
    before do
      publisher.instance_variable_set(:@codec, codec)
      allow(codec).to receive(:encode).with(msg).and_return(msg)
    end

    it 'should encode and publish message with routing_key' do
      expect(codec).to receive(:encode).with(msg)
      expect(exchange).to receive(:publish).with(msg, { routing_key: 'foo', content_type: 'application/json' })
      publisher.publish(msg, routing_key: 'foo')
    end

    it 'should encode and publish message to_queue' do
      expect(codec).to receive(:encode).with(msg)
      expect(exchange).to receive(:publish).with(msg, { routing_key: 'bar', content_type: 'application/json' })
      publisher.publish(msg, to_queue: 'bar')
    end

    it 'should encode and publish message with routing_key over to_queue' do
      expect(codec).to receive(:encode).with(msg)
      expect(exchange).to receive(:publish).with(msg, { routing_key: 'foo', content_type: 'application/json' })
      publisher.publish(msg, to_queue: 'bar', routing_key: 'foo')
    end
  end

  describe '#exchange_name' do
    context 'with defaults' do
      let(:publisher) { described_class.new }

      it 'should have defaults' do
        expect(publisher.exchange_name).to eq 'pika-que'
      end
    end

    context 'with name arg' do
      let(:publisher) { described_class.new(exchange: 'foobar') }

      it 'should have defaults' do
        expect(publisher.exchange_name).to eq 'foobar'
      end
    end
  end
end
