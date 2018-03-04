# > bundle exec ruby examples/demo_retry.rb
require 'pika_que'
require 'pika_que/worker'
require 'pika_que/handlers/retry_handler'

class DemoWorker
  include PikaQue::Worker
  from_queue "pika-que-demo"
  handle_with PikaQue::Handlers::RetryHandler, retry_mode: :const, retry_max_times: 3
  # handle_with PikaQue::Handlers::RetryHandler, retry_mode: :exp, retry_max_times: 2

  def perform(msg)
    logger.info msg["msg"]
    raise "BOOM!"
    ack!
  end

end

PikaQue.logger.level = ::Logger::DEBUG

workers = [DemoWorker]

begin
  pro = PikaQue::Processor.new(workers: workers)
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
