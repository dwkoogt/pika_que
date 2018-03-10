# > bundle exec ruby examples/demo_priority.rb
#
# Priority Queue with message priorities
#
require 'pika_que'
require 'pika_que/worker'

PikaQue.logger.level = ::Logger::DEBUG

class PriorityWorker
  include PikaQue::Worker
  from_queue "pika-que-priority", :arguments => { :'x-max-priority' => 10 }

  def perform(msg)
    logger.info msg['msg']
    ack!
  end

end

begin
  pro = PikaQue::Processor.new(workers: [PriorityWorker], concurrency: 2)
  pro.start
rescue => e
  puts e
  puts e.backtrace.join("\n")
end

sleep 3

pub = PikaQue::Publisher.new()
300.times do |i|
  prty = (i % 2) == 0 ? 1 : 10
  pub.publish({ msg: "hello world #{i} priority #{prty}" }, routing_key: 'pika-que-priority', priority: prty)
end

sleep 3

pro.stop

puts "bye"

exit 1
