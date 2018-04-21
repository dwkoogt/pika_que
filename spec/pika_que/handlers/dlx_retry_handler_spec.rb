require 'spec_helper'

describe PikaQue::Handlers::DLXRetryHandler do
  let(:error_queue) { double('Bunny queue', name: 'dummy-error') }
  let(:error_exchange) { double('Bunny exchange', name: 'dummy-error') }
  let(:retry_queue_60) { double('Bunny queue', name: 'dummy-retry-60') }
  let(:retry_exchange) { double('Bunny exchange', name: 'dummy-retry-60') }
  let(:requeue_exchange) { double('Bunny exchange', name: 'dummy-retry-requeue') }
  let(:channel) { double('Bunny channel', acknowledge: nil, reject: nil, closed?: false) }
  let(:conn) { instance_double(PikaQue::Connection, create_channel: channel) }
  let(:delivery_info) { double('delivery info', delivery_tag: 'tag', routing_key: 'dummy')}
  let(:handler) { described_class.new(retry_prefix: 'dummy') }

  before do
    allow(PikaQue).to receive(:connection).and_return(conn)
    allow(channel).to receive(:exchange).with('dummy-retry-60', type: 'topic', durable: true).and_return(retry_exchange)
    allow(channel).to receive(:exchange).with('dummy-retry-requeue', type: 'topic', durable: true).and_return(requeue_exchange)
    allow(channel).to receive(:exchange).with('dummy-error', type: 'topic', durable: true).and_return(error_exchange)
    allow(channel).to receive(:queue).with("dummy-retry-60", durable: true,
                                        :arguments => {
                                          :'x-dead-letter-exchange' => 'dummy-retry-requeue',
                                          :'x-message-ttl' => 60000
                                        }).and_return(retry_queue_60)
    allow(channel).to receive(:queue).with('dummy-error', durable: true).and_return(error_queue)
    allow(retry_queue_60).to receive(:bind).with(retry_exchange, routing_key: '#' )
    allow(error_queue).to receive(:bind).with(error_exchange, routing_key: '#')
  end

  describe '#initialize' do
    it 'should init with one retry set' do
      expect(channel).to receive(:exchange).with('dummy-retry-60', type: 'topic', durable: true).and_return(retry_exchange)
      expect(channel).to receive(:exchange).with('dummy-retry-requeue', type: 'topic', durable: true).and_return(requeue_exchange)
      expect(channel).to receive(:exchange).with('dummy-error', type: 'topic', durable: true).and_return(error_exchange)
      expect(channel).to receive(:queue).with("dummy-retry-60", durable: true,
                                          :arguments => {
                                            :'x-dead-letter-exchange' => 'dummy-retry-requeue',
                                            :'x-message-ttl' => 60000
                                          }).and_return(retry_queue_60)
      expect(channel).to receive(:queue).with('dummy-error', durable: true).and_return(error_queue)
      expect(retry_queue_60).to receive(:bind).with(retry_exchange, routing_key: '#' )
      expect(error_queue).to receive(:bind).with(error_exchange, routing_key: '#')

      described_class.new(retry_prefix: 'dummy', retry_max_times: 2)
    end
  end

  describe '#bind_queue' do
    let(:worker_queue) { double('Bunny queue', name: 'dummy') }

    it 'should bind worker queue to requeue exchange' do
      expect(worker_queue).to receive(:bind).with(requeue_exchange, routing_key: 'foo')
      handler.bind_queue(worker_queue, 'foo')
    end
  end

  describe '#handle' do
    let(:main_channel) { double('Bunny channel', acknowledge: nil, reject: nil) }

    it 'should acknowledge with ack' do
      expect(main_channel).to receive(:acknowledge).with('tag', false)
      handler.handle(:ack, main_channel, delivery_info, {}, "msg")
    end

    it 'should requeue with reject' do
      expect(main_channel).to receive(:reject).with('tag', true)
      handler.handle(:requeue, main_channel, delivery_info, {}, "msg")
    end

    it 'should handle retry with reject' do
      expect(handler).to receive(:handle_retry).with(main_channel, delivery_info, {}, "msg", :reject)
      handler.handle(:reject, main_channel, delivery_info, {}, "msg")
    end

    it 'should handle retry with error' do
      expect(handler).to receive(:handle_retry).with(main_channel, delivery_info, {}, "msg", RuntimeError)
      handler.handle(:error, main_channel, delivery_info, {}, "msg", RuntimeError)
    end
  end

  describe '#handle_retry' do
    let(:main_channel) { double('Bunny channel', acknowledge: nil, reject: nil) }

    let(:handler) { described_class.new(retry_prefix: 'dummy', retry_max_times: 2) }

    context 'first retry' do
      it 'should publish to retry exchange with count 1' do
        expect(PikaQue.logger).to receive(:info).with('DLXRetryHandler msg=retrying, count=1, headers={}')
        expect(main_channel).to receive(:reject).with('tag', false)
        handler.send :handle_retry, main_channel, delivery_info, {}, "msg", :reject
      end
    end

    context 'second retry' do
      let(:headers) { {"x-death"=>[{"count"=>1, "exchange"=>"dummy-retry-60", "queue"=>"dummy-retry-60", "reason"=>"expired", "routing-keys"=>["dummy"]}, {"count"=>1, "reason"=>"rejected", "queue"=>"dummy", "exchange"=>"dummy", "routing-keys"=>["dummy"]}], "x-first-death-exchange"=>"dummy", "x-first-death-queue"=>"dummy", "x-first-death-reason"=>"rejected"} }
      it 'should publish to retry exchange with count 2' do
        expect(PikaQue.logger).to receive(:info).with("DLXRetryHandler msg=retrying, count=2, headers=#{headers}")
        expect(main_channel).to receive(:reject).with('tag', false)
        handler.send :handle_retry, main_channel, delivery_info, { headers: headers }, "msg", :reject
      end
    end

    context 'last to error' do
      let(:headers) { {"x-death"=>[{"count"=>2, "exchange"=>"dummy-retry-60", "queue"=>"dummy-retry-60", "reason"=>"expired", "routing-keys"=>["dummy"]}, {"count"=>2, "reason"=>"rejected", "queue"=>"dummy", "exchange"=>"dummy", "routing-keys"=>["dummy"]}], "x-first-death-exchange"=>"dummy", "x-first-death-queue"=>"dummy", "x-first-death-reason"=>"rejected"} }
      it 'should publish to error exchange' do
        expect(PikaQue.logger).to receive(:info).with("DLXRetryHandler msg=failing, retried_count=2, headers=#{headers}, reason=reject")
        expect(handler).to receive(:publish_error).with(delivery_info, "msg")
        expect(main_channel).to receive(:acknowledge).with('tag', false)
        handler.send :handle_retry, main_channel, delivery_info, { headers: headers }, "msg", :reject
      end
    end
  end

  describe '#close' do
    it 'should close channel' do
      expect(channel).to receive(:close)
      handler.close
    end
  end

  describe '#publish_error' do
    it 'should publish to error exchange' do
      expect(error_exchange).to receive(:publish).with("msg", routing_key: 'dummy')
      handler.send :publish_error, delivery_info, "msg"
    end
  end
end
