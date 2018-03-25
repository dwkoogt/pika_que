require 'spec_helper'

describe PikaQue::Subscriber do
  class DummyWorker
    include PikaQue::Worker
    from_queue :dummy

    def perform(msg)
      ack!
    end
  end

  let(:queue) { double('Bunny queue', name: 'dummy') }
  let(:channel) { double('Bunny channel') }
  let(:broker) { instance_double(PikaQue::Broker, channel: channel, start: nil, stop: nil, cleanup: nil) }
  let(:default_handler) { instance_double(PikaQue::Handlers::DefaultHandler) }

  before do
    allow(PikaQue::Broker).to receive(:new).and_return(broker)
  end

  describe '#setup_queue' do
    let(:subscriber) { described_class.new }
    before { allow(broker).to receive(:queue).and_return(queue) }

    it 'should create and return a queue' do
      expect(broker).to receive(:queue).with('dummy', durable: true, auto_delete: false, exclusive: false, arguments: { :'x-man' => 10 })
      expect(subscriber.setup_queue('dummy', { arguments: { :'x-man' => 10 } })).to eq(queue)
    end
  end

  describe '#setup_handler' do
    let(:subscriber) { described_class.new }
    before do
      allow(broker).to receive(:queue).and_return(queue)
      allow(broker).to receive(:handler).and_return(default_handler)
    end

    it 'should create and return a handler' do
      subscriber.setup_queue('dummy', {})
      expect(broker).to receive(:handler).with(PikaQue::Handlers::DefaultHandler, {})
      expect(default_handler).to receive(:bind_queue).with(queue, 'dummy')
      subscriber.setup_handler(PikaQue::Handlers::DefaultHandler, {})
    end
  end

  describe '#subscribe' do
    let(:subscriber) { described_class.new(worker_pool: Concurrent::ImmediateExecutor.new) }
    let(:worker) { instance_double(DummyWorker, consumer_arguments: {}) }
    let(:consumer) { double('Bunny consumer') }
    before do
      allow(broker).to receive(:queue).and_return(queue)
      allow(broker).to receive(:handler).and_return(default_handler)
      allow(default_handler).to receive(:bind_queue).with(queue, 'dummy')
      allow(queue).to receive(:subscribe).with(block: false, manual_ack: true, arguments: {}) { |&block| block.call({}, {}, "msg") }
    end

    it 'should create a consumer' do
      expect(queue).to receive(:subscribe).and_return(consumer)
      subscriber.setup_queue('dummy', {})
      subscriber.setup_handler(PikaQue::Handlers::DefaultHandler, {})
      expect(subscriber.subscribe(worker)).to eq consumer
    end

    it 'should call handle_message with args passed to block' do
      expect(subscriber).to receive(:handle_message).with(worker, {}, {}, "msg")
      subscriber.setup_queue('dummy', {})
      subscriber.setup_handler(PikaQue::Handlers::DefaultHandler, {})
      subscriber.subscribe(worker)
    end
  end

  describe '#handle_message' do
    let(:worker) { DummyWorker.new }
    let(:codec) { double('Codec', content_type: 'application/json') }
    let(:metrics) { double('Metrics', measure: nil, increment: nil) }
 
    before do
      subscriber.instance_variable_set(:@codec, codec)
      allow(broker).to receive(:queue).and_return(queue)
      allow(broker).to receive(:handler).and_return(default_handler)
      allow(default_handler).to receive(:bind_queue).with(queue, 'dummy')
      allow(codec).to receive(:decode).with("msg").and_return("msg")
      allow(subscriber).to receive(:metrics).and_return(metrics)
      allow(metrics).to receive(:measure).with("work.DummyWorker.time") { |&block| block.call() }

      subscriber.setup_queue('dummy', {})
      subscriber.setup_handler(PikaQue::Handlers::DefaultHandler, {})
    end

    context 'with defaults' do
      let(:subscriber) { described_class.new }

      it 'should handle with ack' do
        expect(codec).to receive(:decode).and_return("msg")
        expect(metrics).to receive(:measure).with("work.DummyWorker.time")
        expect(worker).to receive(:work).with({}, {}, "msg").and_return(:ack)
        expect(default_handler).to receive(:handle).with(:ack, channel, {}, {}, "msg", nil)
        expect(metrics).to receive(:increment).with("work.DummyWorker.handled.ack")
        expect(metrics).to receive(:increment).with("work.DummyWorker.processed")
        subscriber.handle_message(worker, {}, {}, "msg")
      end
    end

    context 'with no ack' do
      let(:subscriber) { described_class.new(ack: false) }

      it 'should not handle anything' do
        expect(codec).to receive(:decode).and_return("msg")
        expect(metrics).to receive(:measure).with("work.DummyWorker.time")
        expect(worker).to receive(:work).with({}, {}, "msg").and_return(:ack)
        expect(default_handler).to_not receive(:handle).with(:ack, channel, {}, {}, "msg", nil)
        expect(metrics).to receive(:increment).with("work.DummyWorker.handled.noop")
        expect(metrics).to receive(:increment).with("work.DummyWorker.processed")
        subscriber.handle_message(worker, {}, {}, "msg")
      end
    end

    context 'with worker error' do
      let(:subscriber) { described_class.new }
      before { allow(worker).to receive(:work).and_raise("Boom!") }

      it 'should handle and report error' do
        expect(codec).to receive(:decode).and_return("msg")
        expect(metrics).to receive(:measure).with("work.DummyWorker.time")
        expect(worker).to receive(:work).with({}, {}, "msg").and_raise("Boom!") 
        expect(default_handler).to receive(:handle).with(:error, channel, {}, {}, "msg", RuntimeError)
        expect(metrics).to receive(:increment).with("work.DummyWorker.handled.error")
        expect(subscriber).to receive(:notify_reporters).with(RuntimeError, DummyWorker, "msg")
        expect(metrics).to receive(:increment).with("work.DummyWorker.processed")
        subscriber.handle_message(worker, {}, {}, "msg")
      end
    end

    context 'with handler error' do
      let(:subscriber) { described_class.new }
      before do 
        allow(default_handler).to receive(:handle).and_raise("Boom!")
        allow(default_handler).to receive(:class).and_return(PikaQue::Handlers::DefaultHandler)
      end

      it 'should handle and report error' do
        expect(codec).to receive(:decode).and_return("msg")
        expect(metrics).to receive(:measure).with("work.DummyWorker.time")
        expect(worker).to receive(:work).with({}, {}, "msg").and_return(:reject) 
        expect(default_handler).to receive(:handle).with(:reject, channel, {}, {}, "msg", nil).and_raise("Boom!") 
        expect(metrics).to_not receive(:increment).with("work.DummyWorker.handled.reject")
        expect(metrics).to receive(:increment).with("work.DummyWorker.handler.error")
        expect(subscriber).to receive(:notify_reporters).with(RuntimeError, PikaQue::Handlers::DefaultHandler, "msg")
        expect(metrics).to receive(:increment).with("work.DummyWorker.processed")
        subscriber.handle_message(worker, {}, {}, "msg")
      end
    end
  end

  describe '#unsubscribe' do
    let(:subscriber) { described_class.new }
    let(:worker) { instance_double(DummyWorker, consumer_arguments: {}) }
    let(:consumer) { double('Bunny consumer', cancel: nil) }
    before do
      allow(broker).to receive(:queue).and_return(queue)
      allow(broker).to receive(:handler).and_return(default_handler)
      allow(default_handler).to receive(:bind_queue).with(queue, 'dummy')
      allow(queue).to receive(:subscribe).with(block: false, manual_ack: true, arguments: {}).and_return(consumer)
    end

    it 'should cancel consumer' do
      subscriber.setup_queue('dummy', {})
      subscriber.setup_handler(PikaQue::Handlers::DefaultHandler, {})
      subscriber.subscribe(worker)

      expect(consumer).to receive(:cancel)
      subscriber.unsubscribe
      expect(subscriber.instance_variable_get(:@consumer)).to be_nil
    end

  end

  describe '#teardown' do
    context 'with defaults' do
      let(:pool) { instance_double(Concurrent::FixedThreadPool, shutdown: nil, wait_for_termination: nil) }
      before { allow(Concurrent::FixedThreadPool).to receive(:new).and_return(pool) }
      let(:subscriber) { described_class.new }

      it 'should shutdown pool and cleanup and stop broker' do
        expect(pool).to receive(:shutdown)
        expect(pool).to receive(:wait_for_termination)
        expect(broker).to receive(:cleanup)
        expect(broker).to receive(:stop)
        subscriber.teardown
      end
    end

    context 'with worker pool' do
      let(:pool) { double('Thread pool', shutdown: nil, wait_for_termination: nil) }
      let(:subscriber) { described_class.new(worker_pool: pool) }

      it 'should cleanup and stop broker' do
        expect(pool).to_not receive(:shutdown)
        expect(pool).to_not receive(:wait_for_termination)
        expect(broker).to receive(:cleanup)
        expect(broker).to receive(:stop)
        subscriber.teardown
      end
    end
  end
end
