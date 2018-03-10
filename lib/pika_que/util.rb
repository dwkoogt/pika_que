module PikaQue
  module Util
    extend self
    
    def constantize(str)
      return str if (str.is_a?(Class) || str.is_a?(Module))

      names = str.split('::')
      names.shift if names.empty? || names.first.empty?

      names.inject(Object) do |constant, name|
        constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
      end
    end

  end
end
