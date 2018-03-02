module PikaQue
  class Launcher
    include Logging

    def initialize(runnable)
      @runnable = runnable
    end

    def self.launch(runnable)
      if block_given?
        new(runnable).launch { yield }
      else
        new(runnable).launch
      end
    end

    def launch
      @sig_read, @sig_write = IO.pipe

      register_signals

      if block_given?
        yield
      else
        runnable.run
      end

      while readable_io = wait_for_signal
        signal = readable_io.first[0].gets.strip
        handle_signal(signal)
      end
      
    end

    private

    attr_accessor :runnable, :sig_read, :sig_write

    def register_signals
      signals = %w(INT TERM TTIN TSTP)
      if !defined?(::JRUBY_VERSION)
        signals += %w(USR1 USR2)
      end

      signals.each do |sig|
        trap sig do
          sig_write.puts(sig)
        end if Signal.list.keys.include?(sig)
      end
    end

    def wait_for_signal
      IO.select([sig_read])
    end

    def handle_signal(signal)
      case signal
      when 'INT'
        logger.info "Received INT"
        raise Interrupt
      when 'TERM'
        logger.info "Received TERM"
        raise Interrupt
      when 'TTIN'
        logger.info "Received TTIN"
        log_thread_backtraces
      when 'TSTP'
        logger.info "Received TSTP"
        runnable.stop
      when 'USR1'
        logger.info "Received USR1"
        runnable.stop
      when 'USR2'
        logger.info "Received USR2"
        # TODO ?
      end
    end

    def log_thread_backtraces
      Thread.list.each do |thread|
        logger.warn "Thread TID-#{thread.object_id.to_s(36)} #{thread['label']}"
        if thread.backtrace
            logger.warn thread.backtrace.join("\n")
          else
            logger.warn "<no backtrace available>"
          end
      end
    end


  end
end
