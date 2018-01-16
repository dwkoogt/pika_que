class DemoReporter

  def initialize(opts = {})
    STDOUT.sync = true
  end
  
  def call(worker, delivery_info, metadata, msg)
    puts "entering middleware DemoReporter for msg: #{msg}"
    begin
      yield
    rescue => e
      puts "error caught in middleware DemoReporter for msg: #{msg}, error: #{e.message}"
      raise e
    ensure
      puts "leaving middleware DemoReporter for msg: #{msg}"
    end
  end

end
