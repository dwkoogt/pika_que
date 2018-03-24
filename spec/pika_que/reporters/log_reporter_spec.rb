require 'spec_helper'

describe PikaQue::Reporters::LogReporter do
  describe '#report' do
    let(:reporter) { described_class.new }

    it 'should log message' do
      expect(PikaQue.logger).to receive(:error)
      reporter.report(RuntimeError.new('Boom!'), Object, 'msg')
    end
  end
end
