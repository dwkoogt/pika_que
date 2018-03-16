require 'spec_helper'

describe PikaQue::Configuration do
  describe '#initialize' do
    context 'with defaults' do
      let(:config) { described_class.new }

      it 'should have defaults' do
        expect(config[:amqp]).to eq 'amqp://guest:guest@localhost:5672'
        expect(config[:vhost]).to eq '/'
      end
    end

    context 'with ENV["RABBITMQ_URL"]' do
      around do |example|
        amqp = ENV['RABBITMQ_URL']
        ENV['RABBITMQ_URL'] = 'amqp://dummy:dummy@localhost:5672/foobar'
        example.run
        ENV['RABBITMQ_URL'] = amqp
      end
      let(:config) { described_class.new }

      it 'should have values from ENV' do
        expect(config[:amqp]).to eq 'amqp://dummy:dummy@localhost:5672/foobar'
        expect(config[:vhost]).to eq 'foobar'
      end
    end
  end

  describe '#merge!' do
    let(:config) { described_class.new }
    let(:merged) { config.merge!({ exchange: 'dummy', exchange_options: { type: :fanout } }) }

    it 'should be same instance' do
      expect(config).to eq merged
      expect(config[:exchange]).to eq 'dummy'
      expect(config[:exchange_options][:type]).to eq :fanout
    end
  end

  describe '#merge' do
    let(:config) { described_class.new }
    let(:merged) { config.merge({ exchange: 'dummy', exchange_options: { type: :fanout } }) }

    it 'should be same instance' do
      expect(config).to_not eq merged
      expect(config[:exchange]).to eq 'pika-que'
      expect(config[:exchange_options][:type]).to eq :direct
      expect(merged[:exchange]).to eq 'dummy'
      expect(merged[:exchange_options][:type]).to eq :fanout
    end
  end

  describe '#processor' do
    let(:config) { described_class.new }

    context 'with defaults' do
      let(:processor) { config.processor({}) }

      it 'should have defaults' do
        expect(processor[:processor]).to eq PikaQue::Processor
        expect(processor[:workers]).to eq []
      end
    end

    context 'with args' do
      let(:processor) { config.processor({ processor: 'Foo::Bar', workers: ['FooWorker','BarWorker'] }) }

      it 'should have defaults' do
        expect(processor[:processor]).to eq 'Foo::Bar'
        expect(processor[:workers]).to eq ['FooWorker','BarWorker']
      end
    end
  end

  describe '#add_processor' do
    let(:config) { described_class.new }
    before { config.add_processor({ processor: 'Foo::Bar', workers: ['FooWorker','BarWorker'] }) }

    it 'should have added processor' do
      expect(config[:processors].empty?).to be_falsey
      expect(config[:processors].first[:processor]).to eq 'Foo::Bar'
      expect(config[:processors].first[:workers]).to eq ['FooWorker','BarWorker']
    end
  end
end
