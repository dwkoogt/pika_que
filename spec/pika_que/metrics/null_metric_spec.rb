require 'spec_helper'

describe PikaQue::Metrics::NullMetric do
  describe '#increment' do
    let(:metric) { described_class.new }

    it 'does nothing' do
      expect(metric.increment('foo.bar')).to be_nil
    end
  end

  describe '#measure' do
    let(:metric) { described_class.new }

    it 'call the block' do
      expect(metric.measure('foo.bar'){ 1 + 2 }).to eq 3
    end
  end
end
