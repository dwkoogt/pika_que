require 'spec_helper'

describe PikaQue::Metrics::LogMetric do
  describe '#increment' do
    let(:metric) { described_class.new }

    it 'logs count' do
      expect(PikaQue.logger).to receive(:info).with("COUNT: foo.bar 1")
      metric.increment('foo.bar')
    end
  end

  describe '#measure' do
    let(:metric) { described_class.new }

    it 'call the block and log' do
      expect(PikaQue.logger).to receive(:info).with(/TIME: foo.bar/)
      val = 0
      metric.measure('foo.bar'){ val = 1 + 2 }
      expect(val).to eq 3
    end
  end
end
