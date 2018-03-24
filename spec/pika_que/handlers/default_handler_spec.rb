require 'spec_helper'

describe PikaQue::Handlers::DefaultHandler do
  let(:channel) { double('Bunny channel', acknowledge: nil, reject: nil) }
  let(:delivery_info) { double('delivery info', delivery_tag: 'tag')}
  let(:handler) { described_class.new }

  describe '#handle' do
    it 'should acknowledge with ack' do
      expect(channel).to receive(:acknowledge).with('tag', false)
      handler.handle(:ack, channel, delivery_info, {}, "msg")
    end

    it 'should requeue with reject' do
      expect(channel).to receive(:reject).with('tag', true)
      handler.handle(:requeue, channel, delivery_info, {}, "msg")
    end

    it 'should reject with reject' do
      expect(channel).to receive(:reject).with('tag', false)
      handler.handle(:reject, channel, delivery_info, {}, "msg")
    end
  end
end
