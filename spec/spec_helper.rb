$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
end

require 'pika_que'
require 'pika_que/runner'
require 'pika_que/launcher'
require 'pika_que/cli'
