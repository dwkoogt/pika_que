class DemoMiddleware

  def initialize(opts = {})
    STDOUT.sync = true
  end
  
  def call(worker, delivery_info, metadata, msg)
    puts "entering middleware DemoMiddleware for msg: #{msg}"
    begin
      yield
    rescue => e
      puts "error caught in middleware DemoMiddleware for msg: #{msg}, error: #{e.message}"
      raise e
    ensure
      puts "leaving middleware DemoMiddleware for msg: #{msg}"
    end
  end

end
