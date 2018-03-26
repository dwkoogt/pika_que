require 'spec_helper'

describe PikaQue::CLI do
  let(:cli) { described_class.new }

  after do
    PikaQue.reset!
  end

  describe '#parse' do
    it 'should parse' do
      expect(cli).to receive(:init_logger)
      expect(cli).to receive(:daemonize)
      expect(cli).to receive(:write_pid)
      cli.parse
    end
  end

  describe '#run' do
    let(:runner) { instance_double(PikaQue::Runner, run: nil, stop: nil) }
    before do
      allow(PikaQue::Runner).to receive(:new).and_return(runner)
      allow(PikaQue::Launcher).to receive(:launch).with(runner) { runner.run }
    end

    it 'should run' do
      expect(cli).to receive(:load_app)
      expect(PikaQue).to receive(:middleware)
      expect(runner).to receive(:run)
      expect(PikaQue::Launcher).to receive(:launch).with(runner) { runner.run }.and_yield
      expect(cli).to receive(:exit)
      cli.run
    end

    it 'should catch exception and exit' do
      expect(cli).to receive(:load_app)
      expect(PikaQue).to receive(:middleware)
      expect(runner).to receive(:run).and_raise PikaQue::SetupError
      expect(PikaQue::Launcher).to receive(:launch).with(runner) { runner.run }.and_yield
      expect(PikaQue.logger).to receive(:info).with("Shutting down: PikaQue::SetupError received")
      expect(runner).to receive(:stop)
      expect(cli).to receive(:exit)
      cli.run
    end
  end

  describe '#init_logger' do
    context 'with logfile' do
      before { PikaQue.config[:logfile] = 'logfile.log' }

      it 'should init file logger' do
        expect(PikaQue::Logging).to receive(:init_logger).with('logfile.log')
        cli.init_logger
      end
    end

    context 'with quiet option' do
      before { PikaQue.config[:quiet] = true }

      it 'should set log level to warn' do
        expect(PikaQue.logger).to receive(:level=).with(::Logger::WARN)
        cli.init_logger
      end
    end

    context 'with verbose option' do
      before { PikaQue.config[:verbose] = true }

      it 'should set log level to debug' do
        expect(PikaQue.logger).to receive(:level=).with(::Logger::DEBUG)
        cli.init_logger
      end
    end
  end

  describe '#load_app' do
    context 'with defaults' do
      it 'should add delay processor' do
        expect(PikaQue.config).to receive(:add_processor).once
        expect(PikaQue.config).to receive(:delete).with(:delay_options)
        cli.load_app
      end
    end

    context 'with defaults' do
      before { PikaQue.config[:delay] = false }

      it 'should not add delay processor' do
        expect(PikaQue.config).to_not receive(:add_processor)
        expect(PikaQue.config).to receive(:delete).with(:delay_options)
        cli.load_app
      end
    end

    context 'with workers' do
      let(:worker) { double('Worker') }
      before { PikaQue.config[:workers] = [worker] }

      it 'should add worker processor' do
        expect(PikaQue.config).to receive(:add_processor).twice
        expect(PikaQue.config).to receive(:delete).twice
        cli.load_app
      end
    end
  end

  describe '#parse_options' do
    %w(-c --concurrency).each do |option|
      it "supports '#{option}' option" do
        expect(cli.parse_options([option, '4'])[:concurrency]).to eq 4
      end
    end

    %w(-d --daemon).each do |option|
      it "supports '#{option}' option" do
        expect(cli.parse_options([option])[:daemon]).to be_truthy
      end
    end

    %w(-e --environment).each do |option|
      it "supports '#{option}' option" do
        expect(cli.parse_options([option, 'test'])[:environment]).to eq 'test'
      end
    end

    %w(-q --quiet).each do |option|
      it "supports '#{option}' option" do
        expect(cli.parse_options([option])[:quiet]).to be_truthy
      end
    end

    %w(-v --verbose).each do |option|
      it "supports '#{option}' option" do
        expect(cli.parse_options([option])[:verbose]).to be_truthy
      end
    end

    %w(-r --require).each do |option|
      it "supports '#{option}' option" do
        expect(cli.parse_options([option, 'home'])[:require]).to eq 'home'
      end
    end

    %w(-w --worker).each do |option|
      it "supports '#{option}' option" do
        expect(cli.parse_options([option, 'Foo,Bar,Baz'])[:workers]).to eq ['Foo', 'Bar', 'Baz']
      end
    end

    %w(-L --logfile).each do |option|
      it "supports '#{option}' option" do
        expect(cli.parse_options([option, 'log'])[:logfile]).to eq 'log'
      end
    end

    %w(-P --pidfile).each do |option|
      it "supports '#{option}' option" do
        expect(cli.parse_options([option, 'pid'])[:pidfile]).to eq 'pid'
      end
    end
  end
end
