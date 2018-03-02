require 'pika_que/worker'
require 'pika_que/handlers/default_handler'

# explicitly setting default handler (not necessary)

class DevWorker
  include PikaQue::Worker
  from_queue "pika-que-dev"
  handle_with PikaQue::Handlers::DefaultHandler

  def perform(msg)
    logger.info msg["msg"]
    if rand(2) == 1
      raise "BOOM!"
    end
    ack!
  end

end
