require_relative '../../7_line_reversal'

module LRCP
  RSpec.describe Router do
    let(:router) { Router.new(response_queue, ->_{session}) }
    let(:session) { instance_spy Session }
    let(:response_queue) { [] }
    def send(packet) = router.recv(packet)
    let(:close_packet) { Packet.parse(nil, "/close/12345/") }
    let(:connect_packet) { Packet.parse(nil, "/connect/12345/") }
    let(:data_packet) { Packet.parse(nil, "/data/12345/0/hi/") }

    describe '/connect/ message' do
      it { expect{send connect_packet}.to change{router.session_count}.by(1) }
      it 'forwards the packet to the new session' do
        send connect_packet
        expect(session).to have_received(:<<).with(connect_packet)
      end
    end

    describe '/close/ message' do
      context 'when session does not exist' do
        it { expect{send close_packet}.not_to change{router.session_count} }
        it 'responds' do
          send close_packet
          # echoes back same close message
          expect(router.response_queue).to contain_exactly(close_packet)
        end
      end
      context 'when session exists' do
        before {
          send connect_packet
          expect(router).to have_attributes(session_count: 1)
        }
        it { expect{send close_packet}.to change{router.session_count}.from(1).to(0) }
        it 'responds' do
          send close_packet
          expect(router.response_queue).to contain_exactly(close_packet)
        end
      end
    end

    describe '/data/ and /ack/ messages' do
      context 'when session exists' do
        before { send connect_packet }
        it 'forwards to the session' do
          send data_packet
          expect(session).to have_received(:<<).with(data_packet)
        end
      end
      context 'when session does not exist' do
        it 'responds with /close/ message' do
          send data_packet
          expect(router.response_queue).to contain_exactly(close_packet)
        end
      end
    end
  end
end
