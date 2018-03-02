require 'pika_que/worker'
require 'pika_que/handlers/error_handler'

class DemoWorker
  include PikaQue::Worker
  from_queue "pika-que-demo"
  handle_with PikaQue::Handlers::ErrorHandler

  def perform(msg)
    logger.info msg["msg"]
    if rand(2) == 1
      raise "BOOM!"
    end
    ack!
  end

end
