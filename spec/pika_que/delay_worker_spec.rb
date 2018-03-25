require 'spec_helper'

describe PikaQue::DelayWorker do
  let(:queue) { double('Bunny queue', name: 'dummy-delay') }
  let(:channel) { double('Bunny channel') }
  let(:broker) { instance_double(PikaQue::Broker, channel: channel, start: nil, stop: nil, cleanup: nil) }
  let(:handler) { instance_double(PikaQue::Handlers::DelayHandler) }

  before do
    allow(PikaQue::Broker).to receive(:new).and_return(broker)
  end

  describe '#prepare' do
    let(:worker) { described_class.new }

    it 'should setup queue and handler' do
      expect(broker).to receive(:queue).and_return(queue)
      expect(broker).to receive(:handler).and_return(handler)
      expect(handler).to receive(:bind_queue).with(queue, 'dummy-delay')
      worker.prepare
    end
  end

  context 'with queue handler prepared' do
    let(:consumer) { double('Bunny consumer') }
    before do
      allow(broker).to receive(:queue).and_return(queue)
      allow(broker).to receive(:handler).and_return(handler)
      allow(handler).to receive(:bind_queue).with(queue, 'dummy-delay')
    end

    describe '#run' do
      let(:worker) { described_class.new(worker_pool: Concurrent::ImmediateExecutor.new) }
      before do
        allow(queue).to receive(:subscribe).with(block: false, manual_ack: true) { |&block| block.call({}, {}, "msg") }
      end

      it 'should subscribe to queue and return consumer' do
        worker.prepare
        expect(queue).to receive(:subscribe).and_return(consumer)
        worker.run
      end

      it 'should subscribe to queue and run work' do
        worker.prepare
        expect(worker).to receive(:work).with({}, {}, "msg")
        worker.run
      end
    end

    describe '#work' do
      before do
        allow(queue).to receive(:subscribe).with(block: false, manual_ack: true).and_return(consumer)
      end
      let(:worker) { described_class.new }

      it 'should pass work off to handler' do
        worker.start
        expect(handler).to receive(:handle).with(:ack, channel, {}, {}, "msg")
        worker.work({}, {}, "msg")
      end
    end

    describe '#stop' do
      before do
        allow(queue).to receive(:subscribe).with(block: false, manual_ack: true).and_return(consumer)
      end

      context 'with defaults' do
        let(:pool) { instance_double(Concurrent::FixedThreadPool, shutdown: nil, wait_for_termination: nil) }
        before { allow(Concurrent::FixedThreadPool).to receive(:new).and_return(pool) }
        let(:worker) { described_class.new }

        it 'should cancel consumer, shutdown pool, and cleanup and stop broker' do
          worker.start
          expect(consumer).to receive(:cancel)
          expect(pool).to receive(:shutdown)
          expect(pool).to receive(:wait_for_termination)
          expect(broker).to receive(:cleanup)
          expect(broker).to receive(:stop)
          worker.stop
          expect(worker.instance_variable_get(:@consumer)).to be_nil
        end
      end

      context 'with worker_pool' do
        let(:pool) { double('Thread pool', shutdown: nil, wait_for_termination: nil) }
        let(:worker) { described_class.new(worker_pool: pool) }
        
        it 'should cancel consumer, shutdown pool, and cleanup and stop broker' do
          worker.start
          expect(consumer).to receive(:cancel)
          expect(pool).to_not receive(:shutdown)
          expect(pool).to_not receive(:wait_for_termination)
          expect(broker).to receive(:cleanup)
          expect(broker).to receive(:stop)
          worker.stop
          expect(worker.instance_variable_get(:@consumer)).to be_nil
        end
      end
    end
  end

  describe '#start' do
    let(:worker) { described_class.new }

    it 'should call prepare and run' do
      expect(worker).to receive(:prepare)
      expect(worker).to receive(:run)
      worker.start
    end
  end

  describe '#logger' do
    let(:worker) { described_class.new }

    it 'should return a logger' do
      expect(worker.logger).to be_instance_of(Logger)
    end
  end
end
