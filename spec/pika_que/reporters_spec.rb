require 'spec_helper'

describe PikaQue::Reporters do
  class DummyObject
    include PikaQue::Reporters
  end

  after do
    PikaQue.reset!
  end

  describe '#notify_reporters' do
    let(:dummy_object) { DummyObject.new }
    let(:err) { StandardError.new("Boom!") }

    context 'report' do
      let(:reporter) { double('Reporter') }
      before { PikaQue.config[:reporters] << reporter }

      it 'should call report on reporter' do
        expect(reporter).to receive(:report).with(err, Object, 'msg')
        dummy_object.notify_reporters(err, Object, 'msg')
      end
    end

    context 'error' do
      let(:reporter) { double('Reporter') }
      before { PikaQue.config[:reporters] << reporter }
      before { allow(reporter).to receive(:report).and_raise('Boom!') }

      it 'should catch error and log on error' do
        expect(reporter).to receive(:report).with(err, Object, 'msg').and_raise('Boom!')
        dummy_object.notify_reporters(err, Object, 'msg')
      end
    end
  end

end
