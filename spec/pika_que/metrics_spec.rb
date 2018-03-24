require 'spec_helper'

describe PikaQue::Metrics do
  class DummyObject
    include PikaQue::Metrics
  end

  class DummyMetrics; end

  after do
    PikaQue.reset!
    PikaQue::Metrics.instance_variable_set(:@metrics, nil)
  end

  describe '#metrics' do
    let(:dummy_object) { DummyObject.new }

    context 'defaults' do
      it 'should return null metric' do
        expect(dummy_object.metrics).to be_instance_of PikaQue::Metrics::LogMetric
      end
    end

    context 'quiet' do
      before { PikaQue.config[:quiet] = true }

      it 'should return null metric' do
        expect(dummy_object.metrics).to be_instance_of PikaQue::Metrics::NullMetric
      end
    end

    context 'custom' do
      before { PikaQue.config[:metrics] = DummyMetrics }

      it 'should return null metric' do
        expect(dummy_object.metrics).to be_instance_of DummyMetrics
      end
    end
  end
end
