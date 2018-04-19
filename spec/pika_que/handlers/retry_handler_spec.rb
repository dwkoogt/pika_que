require 'spec_helper'

describe PikaQue::Handlers::RetryHandler do
  let(:error_queue) { double('Bunny queue', name: 'dummy-error') }
  let(:error_exchange) { double('Bunny exchange', name: 'dummy-error') }
  let(:retry_queue_60) { double('Bunny queue', name: 'dummy-retry-60') }
  let(:retry_queue_120) { double('Bunny queue', name: 'dummy-retry-120') }
  let(:retry_exchange) { double('Bunny exchange', name: 'dummy-retry') }
  let(:requeue_exchange) { double('Bunny exchange', name: 'dummy-retry-requeue') }
  let(:channel) { double('Bunny channel', acknowledge: nil, reject: nil, closed?: false) }
  let(:conn) { instance_double(PikaQue::Connection, create_channel: channel) }
  let(:delivery_info) { double('delivery info', delivery_tag: 'tag', routing_key: 'tag')}
  let(:handler) { described_class.new(retry_prefix: 'dummy', retry_mode: :const) }

  before do
    allow(PikaQue).to receive(:connection).and_return(conn)
    allow(channel).to receive(:exchange).with('dummy-retry', type: 'headers', durable: true).and_return(retry_exchange)
    allow(channel).to receive(:exchange).with('dummy-retry-requeue', type: 'topic', durable: true).and_return(requeue_exchange)
    allow(channel).to receive(:exchange).with('dummy-error', type: 'topic', durable: true).and_return(error_exchange)
    allow(channel).to receive(:queue).with("dummy-retry-60", durable: true,
                                        :arguments => {
                                          :'x-dead-letter-exchange' => 'dummy-retry-requeue',
                                          :'x-message-ttl' => 60000
                                        }).and_return(retry_queue_60)
    allow(channel).to receive(:queue).with("dummy-retry-120", durable: true,
                                        :arguments => {
                                          :'x-dead-letter-exchange' => 'dummy-retry-requeue',
                                          :'x-message-ttl' => 120000
                                        }).and_return(retry_queue_120)
    allow(channel).to receive(:queue).with('dummy-error', durable: true).and_return(error_queue)
    allow(retry_queue_60).to receive(:bind).with(retry_exchange, arguments: { backoff: 60 } )
    allow(retry_queue_120).to receive(:bind).with(retry_exchange, arguments: { backoff: 120 } )
    allow(error_queue).to receive(:bind).with(error_exchange, routing_key: '#')
  end

  describe '.backoff_periods' do
    it 'should return number array' do
      expect(described_class.backoff_periods(5, 0)).to eq [60, 120, 240, 480, 960]
      expect(described_class.backoff_periods(5, 30)).to eq [180, 360, 720, 1440, 2880]
    end
  end

  describe '.next_ttl' do
    it 'should return next number' do
      expect(described_class.next_ttl(1, 0)).to eq 60
      expect(described_class.next_ttl(2, 0)).to eq 120
      expect(described_class.next_ttl(1, 30)).to eq 180
      expect(described_class.next_ttl(2, 30)).to eq 360
    end
  end

  describe '#initialize' do
    context 'constant backoff mode' do
      it 'should init with one retry set' do
        expect(channel).to receive(:exchange).with('dummy-retry', type: 'headers', durable: true).and_return(retry_exchange)
        expect(channel).to receive(:exchange).with('dummy-retry-requeue', type: 'topic', durable: true).and_return(requeue_exchange)
        expect(channel).to receive(:exchange).with('dummy-error', type: 'topic', durable: true).and_return(error_exchange)
        expect(channel).to receive(:queue).with("dummy-retry-60", durable: true,
                                            :arguments => {
                                              :'x-dead-letter-exchange' => 'dummy-retry-requeue',
                                              :'x-message-ttl' => 60000
                                            }).and_return(retry_queue_60)
        expect(channel).to_not receive(:queue).with("dummy-retry-120", durable: true,
                                            :arguments => {
                                              :'x-dead-letter-exchange' => 'dummy-retry-requeue',
                                              :'x-message-ttl' => 120000
                                            })
        expect(channel).to receive(:queue).with('dummy-error', durable: true).and_return(error_queue)
        expect(retry_queue_60).to receive(:bind).with(retry_exchange, arguments: { backoff: 60 } )
        expect(error_queue).to receive(:bind).with(error_exchange, routing_key: '#')

        described_class.new(retry_prefix: 'dummy', retry_mode: :const, retry_max_times: 2)
      end
    end

    context 'exponential backoff mode' do
      it 'should init with three retry set' do
        expect(channel).to receive(:exchange).with('dummy-retry', type: 'headers', durable: true).and_return(retry_exchange)
        expect(channel).to receive(:exchange).with('dummy-retry-requeue', type: 'topic', durable: true).and_return(requeue_exchange)
        expect(channel).to receive(:exchange).with('dummy-error', type: 'topic', durable: true).and_return(error_exchange)
        expect(channel).to receive(:queue).with("dummy-retry-60", durable: true,
                                            :arguments => {
                                              :'x-dead-letter-exchange' => 'dummy-retry-requeue',
                                              :'x-message-ttl' => 60000
                                            }).and_return(retry_queue_60)
        expect(channel).to receive(:queue).with("dummy-retry-120", durable: true,
                                            :arguments => {
                                              :'x-dead-letter-exchange' => 'dummy-retry-requeue',
                                              :'x-message-ttl' => 120000
                                            }).and_return(retry_queue_120)
        expect(channel).to receive(:queue).with('dummy-error', durable: true).and_return(error_queue)
        expect(retry_queue_60).to receive(:bind).with(retry_exchange, arguments: { backoff: 60 } )
        expect(retry_queue_120).to receive(:bind).with(retry_exchange, arguments: { backoff: 120 } )
        expect(error_queue).to receive(:bind).with(error_exchange, routing_key: '#')

        described_class.new(retry_prefix: 'dummy', retry_mode: :exp, retry_max_times: 2)
      end
    end
  end

  describe '#bind_queue' do
    let(:worker_queue) { double('Bunny queue') }

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

    context 'constant backoff' do
      let(:handler) { described_class.new(retry_prefix: 'dummy', retry_mode: :const, retry_max_times: 2) }

      context 'first retry' do
        it 'should publish to retry exchange with count 1' do
          expect(PikaQue.logger).to receive(:info).with('RetryHandler msg=retrying, count=1, headers={}')
          expect(handler).to receive(:publish_retry).with(delivery_info, "msg", { backoff: 60, count: 1 })
          expect(main_channel).to receive(:acknowledge).with('tag', false)
          handler.send :handle_retry, main_channel, delivery_info, {}, "msg", :reject
        end
      end

      context 'second retry' do
        it 'should publish to retry exchange with count 2' do
          expect(PikaQue.logger).to receive(:info).with('RetryHandler msg=retrying, count=2, headers={"count"=>1}')
          expect(handler).to receive(:publish_retry).with(delivery_info, "msg", { backoff: 60, count: 2 })
          expect(main_channel).to receive(:acknowledge).with('tag', false)
          handler.send :handle_retry, main_channel, delivery_info, { headers: { 'count' => 1 } }, "msg", :reject
        end
      end

      context 'last to error' do
        it 'should publish to error exchange' do
          expect(PikaQue.logger).to receive(:info).with('RetryHandler msg=failing, retried_count=2, headers={"count"=>2}, reason=reject')
          expect(handler).to receive(:publish_error).with(delivery_info, "msg")
          expect(main_channel).to receive(:acknowledge).with('tag', false)
          handler.send :handle_retry, main_channel, delivery_info, { headers: { 'count' => 2 } }, "msg", :reject
        end
      end
    end

    context 'exponential backoff' do
      let(:handler) { described_class.new(retry_prefix: 'dummy', retry_mode: :exp, retry_max_times: 2) }

      context 'first retry' do
        it 'should publish to retry exchange with count 1' do
          expect(PikaQue.logger).to receive(:info).with('RetryHandler msg=retrying, count=1, headers={}')
          expect(handler).to receive(:publish_retry).with(delivery_info, "msg", { backoff: 60, count: 1 })
          expect(main_channel).to receive(:acknowledge).with('tag', false)
          handler.send :handle_retry, main_channel, delivery_info, {}, "msg", :reject
        end
      end

      context 'second retry' do
        it 'should publish to retry exchange with count 2' do
          expect(PikaQue.logger).to receive(:info).with('RetryHandler msg=retrying, count=2, headers={"count"=>1}')
          expect(handler).to receive(:publish_retry).with(delivery_info, "msg", { backoff: 120, count: 2 })
          expect(main_channel).to receive(:acknowledge).with('tag', false)
          handler.send :handle_retry, main_channel, delivery_info, { headers: { 'count' => 1 } }, "msg", :reject
        end
      end

      context 'last to error' do
        it 'should publish to error exchange' do
          expect(PikaQue.logger).to receive(:info).with('RetryHandler msg=failing, retried_count=2, headers={"count"=>2}, reason=reject')
          expect(handler).to receive(:publish_error).with(delivery_info, "msg")
          expect(main_channel).to receive(:acknowledge).with('tag', false)
          handler.send :handle_retry, main_channel, delivery_info, { headers: { 'count' => 2 } }, "msg", :reject
        end
      end
    end
  end

  describe '#close' do
    it 'should close channel' do
      expect(channel).to receive(:close)
      handler.close
    end
  end

  describe '#publish_retry' do
    it 'should publish to retry exchange' do
      expect(retry_exchange).to receive(:publish).with("msg", routing_key: 'tag', headers: { 'count' => 1 })
      handler.send :publish_retry, delivery_info, "msg", { 'count' => 1 }
    end
  end

  describe '#publish_error' do
    it 'should publish to error exchange' do
      expect(error_exchange).to receive(:publish).with("msg", routing_key: 'tag')
      handler.send :publish_error, delivery_info, "msg"
    end
  end
end
