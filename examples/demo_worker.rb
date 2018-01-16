require 'fluffy/worker'
require 'fluffy/handlers/error_handler'

class DemoWorker
  include Fluffy::Worker
  from_queue "fluffy-demo"
  handle_with Fluffy::Handlers::ErrorHandler

  def perform(msg)
    logger.info msg["msg"]
    if rand(2) == 1
      raise "BOOM!"
    end
    ack!
  end

end
