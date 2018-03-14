require 'spec_helper'

describe PikaQue do
  after do
    described_class.reset!
  end

  it 'has a version number' do
    expect(PikaQue::VERSION).not_to be nil
  end

  describe '.config' do
    it 'should return configuration' do
      expect(described_class.config).to be_instance_of(PikaQue::Configuration) 
    end
  end

  describe '.configure' do
    let(:merged) { described_class.configure({ exchange: 'rai-que' }) }
    it 'should merge arg' do
      expect(merged).to be_instance_of(Hash)
      expect(merged[:exchange]).to eq 'rai-que'
      expect(described_class.config[:exchange]).to eq 'rai-que'
    end
  end

  describe '.logger' do
    context 'default logger' do
      it 'should return logger' do
        expect(described_class.logger).to be_instance_of(Logger)
      end
    end

    context 'with a custom logger' do
      let(:dummy_logger) { double("Dummy logger") }

      it 'users the custom logger' do
        described_class.logger = dummy_logger
        expect(described_class.logger).to eq(dummy_logger)
      end
    end
  end

  describe '.connection' do
    before { allow_any_instance_of(PikaQue::Connection).to receive(:connect!).and_return('Bunny') }
    
    it 'should return connection' do
      expect(described_class.connection).to be_instance_of(PikaQue::Connection)
    end
  end

  describe '.middleware' do
    it 'should return middleware chain' do
      expect(described_class.middleware).to be_instance_of(PikaQue::Middleware::Chain)
    end

    it 'should yield middleware chain with block' do
      expect{ |b| described_class.middleware(&b) }.to yield_control
    end
  end

  describe '.reporters' do
    context 'default reporter' do
      it 'should include default reporter if empty' do
        expect(described_class.reporters.first).to be_instance_of(PikaQue::Reporters::LogReporter)
      end
    end

    context 'configured reporter' do
      let(:reporter) { double('Reporter') }
      before { described_class.config[:reporters] << reporter }

      it 'should include configured reporter' do
        expect(described_class.reporters.first).to be(reporter)
      end
    end
    
  end

end
