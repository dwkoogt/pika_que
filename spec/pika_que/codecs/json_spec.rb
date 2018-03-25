require 'spec_helper'

describe PikaQue::Codecs::JSON do
  describe '.encode' do
    it 'should encode json' do
      expect(described_class.encode({ 'foo' => 'bar' })).to eq("{\"foo\":\"bar\"}")
    end
  end

  describe '.decode' do
    it 'should decode json' do
      expect(described_class.decode("{\"foo\":\"bar\"}")).to eq({ 'foo' => 'bar' })
    end
  end

  describe '.content_type' do
    it 'should be application/json' do
      expect(described_class.content_type).to eq('application/json')
    end
  end
end
