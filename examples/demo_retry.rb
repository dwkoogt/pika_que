# > bundle exec ruby examples/demo_retry.rb
require 'fluffy'
require 'fluffy/worker'
require 'fluffy/handlers/retry_handler'

class DemoWorker
  include Fluffy::Worker
  from_queue "fluffy-demo"
  handle_with Fluffy::Handlers::RetryHandler, retry_mode: :const, retry_max_times: 3

  def perform(msg)
    logger.info msg["msg"]
    raise "BOOM!"
    ack!
  end

end

Fluffy.logger.level = ::Logger::DEBUG

workers = [DemoWorker]

begin
  pro = Fluffy::Processor.new(workers: workers)
  pro.start
rescue => e
  puts e
  puts e.backtrace.join("\n")
end

sleep 3

DemoWorker.enqueue({ msg: "retry message" })

sleep 200

pro.stop

puts "bye"

exit 1
