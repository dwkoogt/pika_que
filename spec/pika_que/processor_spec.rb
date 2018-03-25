require 'spec_helper'

describe PikaQue::Processor do
  class DummyWorker
    include PikaQue::Worker
    from_queue :dummy

    def perform(msg)
      ack!
    end
  end

  let(:broker) { instance_double(PikaQue::Broker, start: nil, stop: nil, cleanup: nil) }
  let(:pool) { instance_double(Concurrent::FixedThreadPool) }

  before do
    allow(PikaQue::Broker).to receive(:new).and_return(broker)
    allow(Concurrent::FixedThreadPool).to receive(:new).and_return(pool)
  end

  describe '#setup' do
    let(:processor) { described_class.new(workers: [DummyWorker]) }

    it 'should call prepare on workers' do
      expect_any_instance_of(DummyWorker).to receive(:prepare)
      processor.setup
    end
  end

  describe '#process' do
    let(:processor) { described_class.new(workers: [DummyWorker]) }

    it 'should call prepare on workers' do
      expect_any_instance_of(DummyWorker).to receive(:run)
      processor.process
    end
  end

  describe '#start' do
    let(:processor) { described_class.new(workers: [DummyWorker]) }

    it 'should create a thread and call setup and process' do
      expect(processor).to receive(:setup)
      expect(processor).to receive(:process)
      processor.start.join
    end
  end

  describe '#stop' do
    let(:processor) { described_class.new(workers: [DummyWorker]) }

    it 'should stop and cleanup' do
      expect_any_instance_of(DummyWorker).to receive(:stop)
      expect(pool).to receive(:shutdown)
      expect(pool).to receive(:wait_for_termination).with any_args
      expect(broker).to receive(:cleanup).with(true)
      expect(broker).to receive(:stop)
      processor.stop
    end
  end
end
