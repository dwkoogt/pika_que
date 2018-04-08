require 'pika_que/worker'
require 'pika_que/codecs/rails'

module PikaQue
  class RailsWorker
    include PikaQue::Worker
    config codec: PikaQue::Codecs::RAILS

    def perform(msg)
      ActiveJob::Base.execute msg
      ack!
    end

  end
end
