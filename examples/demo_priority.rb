# > bundle exec ruby examples/demo_priority.rb
require 'pika_que'
require 'pika_que/worker'

PikaQue.logger.level = ::Logger::DEBUG

class HighPriorityWorker
  include PikaQue::Worker
  from_queue "pika-que-priority", :arguments => { :'x-max-priority' => 10 }, :priority => 10

  def perform(msg)
    logger.info msg["msg"]
    ack!
  end

end

class LowPriorityWorker
  include PikaQue::Worker
  from_queue "pika-que-priority", :arguments => { :'x-max-priority' => 10 }, :priority => 1

  def perform(msg)
    logger.info msg["msg"]
    ack!
  end

end

workers = [HighPriorityWorker,LowPriorityWorker]

begin
  pro = PikaQue::Processor.new(workers: workers, concurrency: 10)
  pro.start
rescue => e
  puts e
  puts e.backtrace.join("\n")
end

sleep 3

300.times do |i|
  LowPriorityWorker.enqueue({ msg: "low priority #{i}" })
  HighPriorityWorker.enqueue({ msg: "high priority #{i}" })
end

sleep 3

pro.stop

puts "bye"

exit 1
