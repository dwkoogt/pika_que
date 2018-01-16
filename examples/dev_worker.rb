require 'fluffy/worker'
require 'fluffy/handlers/default_handler'

# explicitly setting default handler (not necessary)

class DevWorker
  include Fluffy::Worker
  from_queue "fluffy-dev"
  handle_with Fluffy::Handlers::DefaultHandler

  def perform(msg)
    logger.info msg["msg"]
    if rand(2) == 1
      raise "BOOM!"
    end
    ack!
  end

end
