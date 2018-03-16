require 'spec_helper'

describe PikaQue::Connection do
  let(:bunny) { double('Bunny session', start: true, connected?: true, close: nil) }

  before do
    allow(Bunny).to receive(:new).and_return(bunny)
  end

  describe '.create' do
    let(:conn) { described_class.create }

    it 'should be a connected instance' do
      expect(conn.connected?).to be_truthy
    end
  end

  describe '#connect!' do
    let(:conn) { described_class.new }

    it 'should start Bunny session' do
      expect(conn.connect!).to eq bunny
      expect(conn.connected?).to be_truthy
    end
  end

  describe '#connected?' do
    let(:conn) { described_class.new }

    it 'should return false' do
      expect(conn.connected?).to be_falsey
    end

    it 'should return true on connect' do
      conn.connect!
      expect(conn.connected?).to be_truthy
    end
  end

  describe '#disconnect!' do
    let(:conn) { described_class.create }

    it 'should close Bunny session' do
      expect(bunny).to receive(:close)
      conn.disconnect!
      expect(conn.connected?).to be_falsey
    end
  end

  describe '#ensure_connection' do
    let(:conn) { described_class.new }

    it 'should start Bunny session' do
      expect(bunny).to receive(:start)
      expect(conn.ensure_connection).to eq bunny
      expect(conn.connected?).to be_truthy
    end
  end
end
