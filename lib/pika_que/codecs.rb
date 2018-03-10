module PikaQue
  module Codecs

    autoload :JSON, 'pika_que/codecs/json'
    autoload :NOOP, 'pika_que/codecs/noop'
    autoload :RAILS, 'pika_que/codecs/rails'

  end
end
