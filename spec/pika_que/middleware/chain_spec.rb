require 'spec_helper'

describe PikaQue::Middleware::Chain do
  class DummyWare
    def call(*args)
      yield
    end
  end

  class MyWare
    def call(*args)
      yield
    end
  end

  let(:chain) { described_class.new }

  describe '#initialize' do
    it 'should yield self with block' do
      expect{ |b| described_class.new(&b) }.to yield_control
    end
  end

  describe '#add' do
    it 'should add to entries' do
      expect{ chain.add DummyWare }.to change{ chain.entries.size }.by 1
    end
  end

  describe '#remove' do
    before { chain.add DummyWare }
    it 'should remove from entries' do
      expect{ chain.remove DummyWare }.to change{ chain.entries.size }.by -1
    end
  end

  describe '#prepend' do
    before { chain.add DummyWare }
    it 'should add to entries as first one' do
      expect{ chain.prepend MyWare }.to change{ chain.entries.size }.by 1
      expect(chain.entries.first.klass).to eq MyWare
    end
  end

  describe '#insert_before' do
    before { chain.add DummyWare }
    it 'should add to entries before DummyWare' do
      expect{ chain.insert_before DummyWare, MyWare }.to change{ chain.entries.size }.by 1
      expect(chain.entries.first.klass).to eq MyWare
    end
  end

  describe '#insert_after' do
    before { chain.add DummyWare }
    it 'should add to entries after DummyWare' do
      expect{ chain.insert_after DummyWare, MyWare }.to change{ chain.entries.size }.by 1
      expect(chain.entries.last.klass).to eq MyWare
    end
  end

  describe '#clear' do
    before { chain.add DummyWare }
    it 'should empty entries' do
      expect{ chain.clear }.to change{ chain.entries.size }.to eq 0
    end
  end

  describe '#invoke' do
    before do
      chain.add(DummyWare)
      chain.add(MyWare)
    end
    it 'should invoke call on middlewares' do
      expect_any_instance_of(DummyWare).to receive(:call).and_call_original
      expect_any_instance_of(MyWare).to receive(:call).and_call_original
      chain.invoke('foo', 'bar'){ 'baz' }
    end
  end

  describe '#initialize_copy' do
    before { chain.add DummyWare }
    let(:copy) { described_class.new }
    it 'should copy entries' do
      expect{ chain.send :initialize_copy, copy }.to change{ copy.entries.size }.by 1
    end
  end
end
