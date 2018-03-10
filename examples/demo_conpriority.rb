# > bundle exec ruby examples/demo_conpriority.rb
# https://www.rabbitmq.com/consumer-priority.html
# https://www.rabbitmq.com/blog/2013/12/16/using-consumer-priorities-with-rabbitmq/
#
# Consumer Priority
# HighPriorityWorker will process more messages than LowPriorityWorker
#
require 'pika_que'
require 'pika_que/worker'
require 'pika_que/runner'

PikaQue.logger.level = ::Logger::DEBUG

class HighPriorityWorker
  include PikaQue::Worker
  from_queue "pika-que-demo", :priority => 10

  def perform(msg)
    logger.info "HighPriorityWorker #{msg['msg']}"
    ack!
  end

end

class LowPriorityWorker
  include PikaQue::Worker
  from_queue "pika-que-demo", :priority => 1

  def perform(msg)
    logger.info "LowPriorityWorker #{msg['msg']}"
    ack!
  end

end

PikaQue.config.add_processor(workers: [LowPriorityWorker], concurrency: 10)
PikaQue.config.add_processor(workers: [HighPriorityWorker], concurrency: 10)

runner = PikaQue::Runner.new

begin
  runner.run
rescue => e
  puts e
  puts e.backtrace.join("\n")
end

sleep 3

pub = PikaQue::Publisher.new()

600.times do |i|
  pub.publish({ msg: "hello world #{i}" }, routing_key: 'pika-que-demo')
end

sleep 3

runner.stop

puts "bye"

exit 1
