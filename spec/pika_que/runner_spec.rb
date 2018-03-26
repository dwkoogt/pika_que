require 'spec_helper'

describe PikaQue::Runner do
  let(:runner) { described_class.new }
  let(:processor) { instance_double(PikaQue::Processor, start: nil, stop: nil) }
  let(:conn) { instance_double(PikaQue::Connection, disconnect!: nil) }

  before do
    allow(PikaQue::Processor).to receive(:new).and_return(processor)
    allow(PikaQue).to receive(:connection).and_return(conn)
    PikaQue.config[:processors] << { processor: PikaQue::Processor }
  end

  after do
    PikaQue.reset!
  end

  describe '#run' do
    it 'should call start on processor' do
      expect(processor).to receive(:start)
      runner.run
    end
  end

  describe '#stop' do
    it 'should call stop on processor and disconnect' do
      runner.run
      expect(processor).to receive(:stop)
      expect(conn).to receive(:disconnect!)
      runner.stop
    end
  end
end
