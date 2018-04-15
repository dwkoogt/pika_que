# > bundle exec ruby examples/demo_delay.rb
require 'pika_que'
require 'pika_que/worker'
require 'pika_que/runner'

class DemoWorker
  include PikaQue::Worker
  from_queue "pika-que-demo"

  def perform(msg)
    logger.info msg["msg"]
    ack!
  end

end

PikaQue.logger.level = ::Logger::DEBUG

PikaQue.config[:processors] << PikaQue.config[:delay_options]
PikaQue.config[:processors] << { workers: [DemoWorker] }

runner = PikaQue::Runner.new
runner.setup_processors

begin
  runner.run
rescue => e
  puts e
  puts e.backtrace.join("\n")
end

sleep 3

DemoWorker.enqueue_at({ msg: "delay message !!!" }, (Time.now + 180).to_i)

sleep 200

runner.stop

puts "bye"

exit 1
