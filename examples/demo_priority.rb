# > bundle exec ruby examples/demo_priority.rb
require 'fluffy'
require 'fluffy/worker'

Fluffy.logger.level = ::Logger::DEBUG

class HighPriorityWorker
  include Fluffy::Worker
  from_queue "fluffy-priority", :arguments => { :'x-max-priority' => 10 }, :priority => 10

  def perform(msg)
    logger.info msg["msg"]
    ack!
  end

end

class LowPriorityWorker
  include Fluffy::Worker
  from_queue "fluffy-priority", :arguments => { :'x-max-priority' => 10 }, :priority => 1

  def perform(msg)
    logger.info msg["msg"]
    ack!
  end

end

workers = [HighPriorityWorker,LowPriorityWorker]

begin
  pro = Fluffy::Processor.new(workers: workers, concurrency: 10)
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
