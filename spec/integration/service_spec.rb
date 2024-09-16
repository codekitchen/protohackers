require_relative '../../7_line_reversal'

class Waiter < Async::Notification
  def to_proc = proc{signal}
end

module LRCP
  RSpec.describe Service do
    # making a functioning fake for this UDPSocket is higher-effort because
    # it needs to play nicely with Async. So I'm using real sockets for
    # these specs.
    let(:port) { rand(1500..30000) }
    let(:peer) { UDPSocket.new.tap{_1.timeout=0.2} }
    let(:sock) { UDPSocket.new.tap{_1.bind('127.0.0.1', port)} }
    def send(msg) = peer.send(msg, 0, '127.0.0.1', port)
    subject(:service) { Service.new(sock:) }
    let(:waiter) { Waiter.new }

    around do |ex|
      Async do
        Timeout.timeout(1) {ex.run}
      end.wait
    end

    context 'incoming messages' do
      let(:connect) { "/connect/12345/" }
      it 'forwards packets to the router' do
        expect(service.router).to receive(:recv, &waiter).with(having_attributes serialize: connect)
        task = service.run
        send(connect)
        waiter.wait
      ensure
        task&.stop
      end

      it 'makes new sockets availabe to #accept' do
        packet = Packet.parse(nil, '/connect/12345/')
        task = service.run
        sess = service.router.create_session.(packet)
        app_io = service.accept
        expect(sess.app_io).to eq(app_io)
      ensure
        task&.stop
      end
    end
  end
end
