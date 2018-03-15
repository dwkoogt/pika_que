require 'spec_helper'

describe PikaQue::Logging do
  class DummyObject
    include PikaQue::Logging
  end

  describe '.logger' do
    context 'with the default logger' do
      subject { described_class.logger }

      it { is_expected.to be_instance_of(Logger) }
    end

    context 'with a custom logger' do
      let(:dummy_logger) { double("Dummy logger") }
      after { described_class.logger = nil }

      it "users the custom logger" do
        described_class.logger = dummy_logger
        expect(described_class.logger).to eq(dummy_logger)
      end
    end
  end

  describe '#logger' do
    let(:dummy_object) { DummyObject.new }

    it "returns a logger" do
      expect(dummy_object.logger).to be_instance_of(Logger)
    end
  end

  describe '#call' do
    let(:formatter) { PikaQue::Logging::PikaQueFormatter.new }
    let(:t) { Time.now }
    it "returns a formatted log message" do
      expect(formatter.call('info', t, "pika-que", "boom!")).to eq "#{t.utc.iso8601} #{Process.pid} T-#{Thread.current.object_id.to_s(36)} info: boom!\n"
    end
  end
  
end
