require 'spec_helper'

describe PikaQue::Worker do
  class DummyWorker
    include PikaQue::Worker
    from_queue :dummy

    def perform(msg)
    end
  end

  after do
    DummyWorker.from_queue :dummy
    DummyWorker.handle_with nil
    DummyWorker.config nil
  end

  let(:dummy_worker) { DummyWorker }

  describe 'class methods' do
    describe 'with defaults' do
      it 'should have queue name and defaults' do
        expect(dummy_worker.queue_name).to eq 'dummy'
        expect(dummy_worker.queue_opts.empty?).to be_truthy
        expect(dummy_worker.handler_class).to be_nil
        expect(dummy_worker.handler_opts).to be_nil
        expect(dummy_worker.priority).to be_nil
        expect(dummy_worker.local_config).to be_nil
      end
    end

    describe '.from_queue' do
      before do
        dummy_worker.from_queue :dummy, arguments: { :'x-man' => 10 }, priority: 9
      end

      it 'should have queue_name, queue_opts, and priority' do
        expect(dummy_worker.queue_name).to eq 'dummy'
        expect(dummy_worker.queue_opts).to eq({ arguments: { :'x-man' => 10 } })
        expect(dummy_worker.priority).to eq 9
      end
    end

    describe '.handle_with' do
      before do
        dummy_worker.handle_with PikaQue::Handlers::DefaultHandler, retry_times: 5, delay_period: 1000
      end

      it 'should have handler_class and handler_opts' do
        expect(dummy_worker.handler_class).to eq PikaQue::Handlers::DefaultHandler
        expect(dummy_worker.handler_opts).to eq({ retry_times: 5, delay_period: 1000 })
      end
    end

    describe '.config' do
      before do
        dummy_worker.config override: true
      end

      it 'should have local_config' do
        expect(dummy_worker.local_config).to eq({ override: true })
      end
    end

    context 'publish message' do
      let(:publisher) { instance_double(PikaQue::Publisher) }
      before { allow(PikaQue::Publisher).to receive(:new).and_return(publisher) }
      after { dummy_worker.instance_variable_set :@publisher, nil }

      describe '.enqueue' do
        it 'should publish message' do
          expect(publisher).to receive(:publish).with("hello world!", { to_queue: 'dummy', routing_key: nil, priority: nil })
          dummy_worker.enqueue("hello world!")
        end

        it 'should publish message with routing_key' do
          expect(publisher).to receive(:publish).with("hello world!", { to_queue: 'dummy', routing_key: 'fool', priority: nil })
          dummy_worker.enqueue("hello world!", routing_key: 'fool')
        end

        it 'should publish message with priority' do
          expect(publisher).to receive(:publish).with("hello world!", { to_queue: 'dummy', routing_key: nil, priority: 10 })
          dummy_worker.enqueue("hello world!", priority: 10)
        end
      end

      describe '.enqueue_at' do
        before { allow(publisher).to receive(:exchange_name).and_return('dummy') }

        it 'should publish message with timestamp' do
          expect(publisher).to receive(:publish).with("hello world!", { to_queue: 'dummy-delay', headers: { work_at: 100000000, work_queue: 'dummy' } })
          dummy_worker.enqueue_at("hello world!", 100000000)
        end

        it 'should publish message with timestamp and routing_key' do
          expect(publisher).to receive(:publish).with("hello world!", { to_queue: 'dummy-delay', headers: { work_at: 100000000, work_queue: 'fool' } })
          dummy_worker.enqueue_at("hello world!", 100000000, routing_key: 'fool')
        end
      end
    end
  end

  describe 'instance methods' do
    let(:subscriber) { instance_double(PikaQue::Subscriber) }
    before { allow(PikaQue::Subscriber).to receive(:new).and_return(subscriber) }

    context 'with defaults' do
      let(:worker) { dummy_worker.new }

      describe '#prepare' do
        it 'should setup queue and handler on subscriber' do
          expect(subscriber).to receive(:setup_queue).with('dummy', {})
          expect(subscriber).to receive(:setup_handler).with(nil, {})
          worker.prepare
        end
      end

      describe '#run' do
        it 'should subscribe with self(worker)' do
          expect(subscriber).to receive(:subscribe).with(worker)
          worker.run
        end
      end

      describe '#start' do
        it 'should invoke prepare and run' do
          expect(worker).to receive(:prepare).and_return true
          expect(worker).to receive(:run).and_return true
          worker.start
        end
      end

      describe '#stop' do
        it 'should unsubscribe and teardown' do
          expect(subscriber).to receive(:unsubscribe)
          expect(subscriber).to receive(:teardown)
          worker.stop
        end
      end

      describe '#work' do
        it 'should invoke perform with message' do
          expect(worker).to receive(:perform).with("hello world!")
          worker.work({}, {}, "hello world!")
        end
      end

      describe '#consumer_arguments' do
        it 'should return a hash' do
          expect(worker.consumer_arguments).to eq({})
        end
      end

      describe '#logger' do
        it 'should return a logger' do
          expect(worker.logger).to be_instance_of(Logger)
        end
      end
    end

    context 'with queue arguments' do
      before do
        dummy_worker.from_queue :dummy, arguments: { :'x-man' => 10 }, priority: 9
        dummy_worker.handle_with PikaQue::Handlers::DefaultHandler, retry_times: 5, delay_period: 1000
      end
      let(:worker) { dummy_worker.new }

      describe '#prepare' do
        it 'should setup queue and handler on subscriber with args' do
          expect(subscriber).to receive(:setup_queue).with('dummy', { arguments: { :'x-man' => 10 } })
          expect(subscriber).to receive(:setup_handler).with(PikaQue::Handlers::DefaultHandler, { retry_times: 5, delay_period: 1000 })
          worker.prepare
        end
      end

      describe '#consumer_arguments' do
        it 'should return a hash with priority args' do
          expect(worker.consumer_arguments).to eq({ :'x-priority' => 9 })
        end
      end
    end
  end

end
