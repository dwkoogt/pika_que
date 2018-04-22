# > bundle exec ruby examples/demo.rb
$: << File.expand_path('../examples', File.dirname(__FILE__))
require 'pika_que'
require 'pika_que/processor'
require 'pika_que/publisher'

require 'dev_worker'
require 'demo_worker'
require 'demo_middleware'

PikaQue.logger.level = ::Logger::DEBUG

PikaQue.middleware do |chain|
  chain.add DemoMiddleware
end

workers = [DemoWorker,DevWorker]

begin
  pro = PikaQue::Processor.new(workers: workers, concurrency: 2)
  pro.start
rescue => e
  puts e
  puts e.backtrace.join("\n")
end

sleep 3

pub = PikaQue::Publisher.new()
300.times do |i|
  pub.publish({ msg: "hello world #{i}" }, routing_key: 'pika-que-dev')
  pub.publish({ msg: "hola mundo #{i}" }, routing_key: 'pika-que-demo')
  # ph.publish({ msg: "hello world #{i} wait" }, routing_key: 'pika-que-dev', expiration: 10000)
end

sleep 3

pro.stop

puts "bye"

exit 1
