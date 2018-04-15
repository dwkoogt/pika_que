require 'spec_helper'

describe PikaQue::Runner do
  let(:runner) { described_class.new }
  let(:processor) { instance_double(PikaQue::Processor, start: nil, stop: nil) }
  let(:conn) { instance_double(PikaQue::Connection, disconnect!: nil) }

  before do
    allow(PikaQue::Processor).to receive(:new).and_return(processor)
    allow(PikaQue).to receive(:connection).and_return(conn)
  end

  after do
    PikaQue.reset!
  end

  describe '#run' do
    before { runner.add_processor processor: PikaQue::Processor }

    it 'should call start on processor' do
      expect(processor).to receive(:start)
      runner.run
    end
  end

  describe '#stop' do
    before { runner.add_processor processor: PikaQue::Processor }

    it 'should call stop on processor and disconnect' do
      runner.run
      expect(processor).to receive(:stop)
      expect(conn).to receive(:disconnect!)
      runner.stop
    end
  end

  describe '#processor' do
    context 'with defaults' do
      let(:processor) { runner.processor({}) }

      it 'should have defaults' do
        expect(processor[:processor]).to eq PikaQue::Processor
        expect(processor[:workers]).to eq []
      end
    end

    context 'with args' do
      let(:processor) { runner.processor({ processor: 'Foo::Bar', workers: ['FooWorker','BarWorker'] }) }

      it 'should have defaults' do
        expect(processor[:processor]).to eq 'Foo::Bar'
        expect(processor[:workers]).to eq ['FooWorker','BarWorker']
      end
    end
  end

  describe '#add_processor' do
    before { runner.add_processor({ processor: 'Foo::Bar', workers: ['FooWorker','BarWorker'] }) }

    it 'should have added processor' do
      expect(runner.processors.empty?).to be_falsey
      expect(runner.processors.first[:processor]).to eq 'Foo::Bar'
      expect(runner.processors.first[:workers]).to eq ['FooWorker','BarWorker']
    end
  end

  describe '#setup_processors' do
    context 'with defaults' do
      it 'should add delay processor' do
        expect(runner).to receive(:add_processor).once
        runner.setup_processors
      end
    end

    context 'with defaults' do
      before { PikaQue.config[:delay] = false }

      it 'should not add delay processor' do
        expect(runner).to_not receive(:add_processor)
        runner.setup_processors
      end
    end

    context 'with workers' do
      let(:worker) { double('Worker') }
      before { PikaQue.config[:workers] = [worker] }

      it 'should add worker processor' do
        expect(runner).to receive(:add_processor).twice
        runner.setup_processors
      end
    end
  end
end
