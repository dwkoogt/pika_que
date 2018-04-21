# > bundle exec ruby examples/demo_dlx_retry.rb
# Retry using x-dead-letter-exchange
# Constant backoff only
require 'pika_que'
require 'pika_que/worker'
require 'pika_que/handlers/dlx_retry_handler'

class DlxWorker
  include PikaQue::Worker
  from_queue "pika-que-dlx", :arguments => { :'x-dead-letter-exchange' => 'pika-que-retry-60' }
  handle_with PikaQue::Handlers::DLXRetryHandler, retry_max_times: 3, retry_dlx: 'pika-que-retry-60'

  def perform(msg)
    logger.info msg["msg"]
    raise "BOOM!"
    ack!
  end

end

PikaQue.logger.level = ::Logger::DEBUG

workers = [DlxWorker]

begin
  pro = PikaQue::Processor.new(workers: workers)
  pro.start
rescue => e
  puts e
  puts e.backtrace.join("\n")
end

sleep 3

DlxWorker.enqueue({ msg: "retry message" })

sleep 200

pro.stop

puts "bye"

exit 1
