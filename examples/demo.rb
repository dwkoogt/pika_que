# > bundle exec ruby examples/demo.rb
$: << File.expand_path('../examples', File.dirname(__FILE__))
require 'fluffy'
require 'fluffy/processor'
require 'fluffy/publisher'

require 'dev_worker'
require 'demo_worker'
require 'demo_reporter'

Fluffy.middleware do |chain|
  chain.add DemoReporter
end

workers = [DemoWorker,DevWorker]

begin
  pro = Fluffy::Processor.new(workers: workers, concurrency: 2)
  pro.start
rescue => e
  puts e
  puts e.backtrace.join("\n")
end

sleep 3

pub = Fluffy::Publisher.new()
300.times do |i|
  pub.publish({ msg: "hello world #{i}" }, routing_key: 'fluffy-dev')
  pub.publish({ msg: "hola mundo #{i}" }, routing_key: 'fluffy-demo')
  # ph.publish({ msg: "hello world #{i} wait" }, routing_key: 'fluffy-dev', expiration: 10000)
end

sleep 3

pro.stop

puts "bye"

exit 1
