require 'spec_helper'

describe PikaQue::Handlers::DelayHandler do
  let(:root_exchange) { double('Bunny exchange', name: 'dummy') }
  let(:delay_queue_60) { double('Bunny queue', name: 'dummy-retry-60') }
  let(:delay_exchange) { double('Bunny exchange', name: 'dummy-delay') }
  let(:requeue_exchange) { double('Bunny exchange', name: 'dummy-delay-requeue') }
  let(:channel) { double('Bunny channel', acknowledge: nil, reject: nil, closed?: false) }
  let(:conn) { instance_double(PikaQue::Connection, create_channel: channel) }
  let(:delivery_info) { double('delivery info', delivery_tag: 'dummy-delay', routing_key: 'dummy-delay')}
  let(:handler) { described_class.new(exchange: 'dummy', delay_periods: [60]) }

  before do
    allow(PikaQue).to receive(:connection).and_return(conn)
    allow(channel).to receive(:exchange).with('dummy-delay', type: 'headers', durable: true).and_return(delay_exchange)
    allow(channel).to receive(:exchange).with('dummy-delay-requeue', type: 'topic', durable: true).and_return(requeue_exchange)
    allow(channel).to receive(:exchange).with('dummy', type: 'direct', durable: true).and_return(root_exchange)
    allow(channel).to receive(:queue).with("dummy-delay-60", durable: true,
                                        :arguments => {
                                          :'x-dead-letter-exchange' => 'dummy-delay-requeue',
                                          :'x-message-ttl' => 60000
                                        }).and_return(delay_queue_60)
    allow(delay_queue_60).to receive(:bind).with(delay_exchange, arguments: { delay: 60 } )
  end

  describe '#initialize' do
    it 'should init with one delay set' do
      expect(channel).to receive(:exchange).with('dummy-delay', type: 'headers', durable: true).and_return(delay_exchange)
      expect(channel).to receive(:exchange).with('dummy-delay-requeue', type: 'topic', durable: true).and_return(requeue_exchange)
      expect(channel).to receive(:exchange).with('dummy', type: 'direct', durable: true).and_return(root_exchange)
      expect(channel).to receive(:queue).with("dummy-delay-60", durable: true,
                                          :arguments => {
                                            :'x-dead-letter-exchange' => 'dummy-delay-requeue',
                                            :'x-message-ttl' => 60000
                                          }).and_return(delay_queue_60)
      expect(delay_queue_60).to receive(:bind).with(delay_exchange, arguments: { delay: 60 } )

      described_class.new(exchange: 'dummy', delay_periods: [60])
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

    context 'delay for 60 sec' do
      let(:work_at) { (Time.now + 100000).to_f }

      it 'should publish to delay exchange' do
        expect(PikaQue.logger).to receive(:info).with(/DelayHandler msg=delaying, delay=60, headers=/)
        expect(handler).to receive(:publish_delay).with(delivery_info, "msg", { 'delay' => 60, 'work_at' => work_at })
        expect(main_channel).to receive(:acknowledge).with('dummy-delay', false)
        handler.send :handle, :ack, main_channel, delivery_info, { headers: { 'work_at' => work_at } }, "msg"
      end
    end

    context 'send to work queue' do
      let(:work_at) { (Time.now + 10).to_f }

      it 'should publish to root exchange' do
        expect(PikaQue.logger).to receive(:info).with(/DelayHandler msg=publishing, queue=dummy, headers=/)
        expect(handler).to receive(:publish_work).with("dummy", "msg")
        expect(main_channel).to receive(:acknowledge).with('dummy-delay', false)
        handler.send :handle, :ack, main_channel, delivery_info, { headers: { 'work_at' => work_at, 'work_queue' => 'dummy' } }, "msg"
      end
    end
  end

  describe '#close' do
    it 'should close channel' do
      expect(channel).to receive(:close)
      handler.close
    end
  end

  describe '#publish_delay' do
    it 'should publish to delay exchange' do
      expect(delay_exchange).to receive(:publish).with("msg", routing_key: 'dummy-delay', headers: { 'delay' => 60, 'work_queue' => 'dummy', 'work_at' => 1000000 })
      handler.send :publish_delay, delivery_info, "msg", { 'delay' => 60, 'work_queue' => 'dummy', 'work_at' => 1000000 }
    end
  end

  describe '#publish_work' do
    it 'should publish to root exchange' do
      expect(root_exchange).to receive(:publish).with("msg", routing_key: 'dummy')
      handler.send :publish_work, "dummy", "msg"
    end
  end
end
