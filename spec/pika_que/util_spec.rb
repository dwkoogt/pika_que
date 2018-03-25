require 'spec_helper'

describe PikaQue::Util do
  module Foo
    class Bar
    end
  end

  class Baz; end

  describe '.constantize' do
    it 'should return module for module' do
      expect(described_class.constantize(Foo)).to eq Foo
    end

    it 'should return module for module name' do
      expect(described_class.constantize('Foo')).to eq Foo
    end

    it 'should return class for class' do
      expect(described_class.constantize(Baz)).to eq Baz
    end

    it 'should return class for class name' do
      expect(described_class.constantize('Baz')).to eq Baz
    end

    it 'should return module class for module class' do
      expect(described_class.constantize(Foo::Bar)).to eq Foo::Bar
    end

    it 'should return moduel class for module class name' do
      expect(described_class.constantize('Foo::Bar')).to eq Foo::Bar
    end
  end
end
