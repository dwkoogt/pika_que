# > bundle exec ruby examples/demo_delay.rb
require 'fluffy'
require 'fluffy/worker'
require 'fluffy/runner'

class DemoWorker
  include Fluffy::Worker
  from_queue "fluffy-demo"

  def perform(msg)
    logger.info msg["msg"]
    ack!
  end

end

Fluffy.logger.level = ::Logger::DEBUG

Fluffy.config.add_processor(Fluffy.config.delete(:delay_options))
Fluffy.config.add_processor(workers: [DemoWorker])

runner = Fluffy::Runner.new

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
