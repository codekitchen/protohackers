require_relative '../../7_line_reversal'

module LRCP
  RSpec.describe Session do
    subject(:session) { Session.new(response_queue, packet("/connect/12345/")) }
    let(:response_queue) { [] }
    let(:conn) { :stub_connection }
    let(:app_io) { session.app_io }
    around do |ex|
      Async do
        task = Async {session.run(retransmit_timeout: 0.1, session_timeout: 0.3)}
        session.app_io.timeout = 0.2
        Timeout.timeout(1) {ex.run}
      ensure
        session.app_io.close
        task.stop if task.running?
        task.wait
      end.wait
    end
    def packet(msg) = Packet.parse(conn, msg)
    def wait = Async::Task.current.yield
    def wait_for_session = (wait until session.caught_up?)

    context 'when receiving /connect/ packet' do
      before { session << packet("/connect/12345/") }
      it "should ack back" do
        wait_for_session
        expect(response_queue).to contain_exactly(packet "/ack/12345/0/")
      end
    end

    context 'when receiving /data/ packet' do
      context 'when the data is out of order' do
        before do
          session << packet("/data/12345/0/hello\n/")
          session << packet("/data/12345/15/whoops\n/")
        end
        it 'acks again to ask for missing data' do
          wait_for_session
          expect(response_queue).to contain_exactly(
            packet("/ack/12345/6/"),
            packet("/ack/12345/6/"),
          )
        end
        it 'does not send the data to the app' do
          expect(app_io.gets).to eq("hello\n")
          # nothing available to read
          expect{app_io.read_nonblock(1)}.to raise_error(IO::EAGAINWaitReadable)
        end
      end
      context 'when the data is in order' do
        before {session << packet("/data/12345/0/hello\n/")}
        it 'sends the data to the app' do
          expect(app_io.gets).to eq("hello\n")
        end
        it 'acks the data' do
          wait_for_session
          expect(response_queue).to contain_exactly(packet "/ack/12345/6/")
        end
      end
      context 'when overlapping data is received' do
        before do
          session << packet("/data/12345/0/hello\n/")
          session << packet("/data/12345/2/llo\nthere\n/")
        end
        it 'sends non-overlapping data to the app' do
          lines = [app_io.gets, app_io.gets]
          expect(lines).to eq ["hello\n", "there\n"]
        end
      end
    end

    context 'when receiving /ack/ packet' do
      context 'len = payload sent' do
        it 'will not re-send the ackd data' do
          app_io.puts "hello"
          wait until session.bytes_sent == 6
          response_queue.clear
          session << packet("/ack/12345/6/")
          # make sure it's _never_ sent, without sleeping
          app_io.close
          session.close.wait
          expect(response_queue).to be_empty
        end
      end
      context 'len < payload sent' do
        it 'will re-send not-yet-ackd data' do
          app_io.puts "hello"
          wait until session.bytes_sent == 6
          session << packet("/ack/12345/3/")
          response_queue.clear
          wait while response_queue.empty?
          expect(response_queue).to include(packet("/data/12345/3/lo\n/"))
        end
      end
      context 'len > payload sent' do
        before { session << packet("/ack/12345/15/") }
        it 'closes the session' do
          wait_for_session
          expect(response_queue).to contain_exactly(packet "/close/12345/")
        end
      end
    end

    it 'sets up app io streams' do
      app_io.puts "hello"
      wait until session.bytes_sent > 0
      expect(response_queue).to contain_exactly(packet "/data/12345/0/hello\n/")
    end

    it 'times out idle sessions' do
      wait while response_queue.empty?
      expect(response_queue).to eq [packet("/close/12345/")]
    end
  end
end
