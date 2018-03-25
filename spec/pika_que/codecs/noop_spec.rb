require 'spec_helper'

describe PikaQue::Codecs::NOOP do
  describe '.encode' do
    it 'should return arg as is' do
      expect(described_class.encode("payload")).to eq "payload"
    end
  end

  describe '.decode' do
    it 'should return arg as is' do
      expect(described_class.decode("payload")).to eq "payload"
    end
  end

  describe '.content_type' do
    it 'should be nil' do
      expect(described_class.content_type).to be_nil
    end
  end
end
