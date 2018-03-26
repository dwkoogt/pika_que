require 'spec_helper'

describe PikaQue::Launcher do
  let(:runner) { instance_double(PikaQue::Runner, run: nil) }

  describe '.launch' do
    let(:launcher) { described_class.new(runner) }
    before { allow(PikaQue::Launcher).to receive(:new).with(runner).and_return(launcher) }

    it 'should init and call launch' do
      expect(launcher).to receive(:launch)
      described_class.launch(runner)
    end

    it 'should init and call launch and yeild with block' do
      expect(launcher).to receive(:launch).and_yield
      described_class.launch(runner) {}
    end
  end

  describe '#launch' do
    let(:sig_read) { double('IO') }
    let(:sig_write) { double('IO') }
    before do
      allow(IO).to receive(:pipe).and_return([sig_read, sig_write])
      allow(launcher).to receive(:wait_for_signal).and_return(false)
    end

    context 'default' do
      let(:launcher) { described_class.new(runner) }

      it 'should register signals and run runner' do
        expect(runner).to receive(:run)
        launcher.launch
      end
    end

    context 'with block' do
      let(:launcher) { described_class.new(runner) }
      before { allow(launcher).to receive(:launch) { runner.run } }

      it 'should register signals and run runner' do
        expect(runner).to receive(:run)
        expect(launcher).to receive(:launch).and_call_original
        launcher.launch { runner.run }
      end
    end
  end

  describe '#handle_signal' do
    let(:launcher) { described_class.new(runner) }

    it 'should raise Interrupt with INT' do
      expect(PikaQue.logger).to receive(:info).with("Received INT")
      begin
        expect(launcher.send :handle_signal, 'INT').to_raise(Interrupt)
      rescue Exception => e      
      end
    end

    it 'should raise Interrupt with TERM' do
      expect(PikaQue.logger).to receive(:info).with("Received TERM")
      begin
        expect(launcher.send :handle_signal, 'TERM').to_raise(Interrupt)
      rescue Exception => e      
      end
    end

    it 'should log thread backtrace with TTIN' do
      expect(PikaQue.logger).to receive(:info).with("Received TTIN")
      expect(launcher).to receive(:log_thread_backtraces)
      launcher.send :handle_signal, 'TTIN'
    end

    it 'should call stop on runnable with TSTP' do
      expect(PikaQue.logger).to receive(:info).with("Received TSTP")
      expect(runner).to receive(:stop)
      launcher.send :handle_signal, 'TSTP'
    end

    it 'should call stop on runnable with USR1' do
      expect(PikaQue.logger).to receive(:info).with("Received USR1")
      expect(runner).to receive(:stop)
      launcher.send :handle_signal, 'USR1'
    end

    it 'should figure out what to do with USR2' do
      expect(PikaQue.logger).to receive(:info).with("Received USR2")
      launcher.send :handle_signal, 'USR2'
    end
  end

  describe '#log_thread_backtraces' do
    let(:launcher) { described_class.new(runner) }

    context 'with backtrace' do
      it 'should log warnings' do
        expect(PikaQue.logger).to receive(:warn).twice
        launcher.send :log_thread_backtraces
      end
    end

    context 'with backtrace' do
      before { allow_any_instance_of(Thread).to receive(:backtrace).and_return(false) }
      it 'should log warnings' do
        expect(PikaQue.logger).to receive(:warn).twice
        launcher.send :log_thread_backtraces
      end
    end
  end
end
