require_relative '../../7_line_reversal'

RSpec.describe 'Line Reversal API' do
  let(:port) { rand(1500..30000) }
  let(:peer) { UDPSocket.new.tap{_1.timeout=0.2} }
  def send(msg) = peer.send(msg, 0, '127.0.0.1', port)
  def recv
    peer.recv(1000)
  rescue IO::TimeoutError
    raise "no message received within timeout"
  end

  around do |ex|
    Async do
      svc = server(port:)
      ex.run
    ensure
      svc.stop if svc.running?
      svc.wait
    end.wait
  end

  it 'responds with reversed strings via LRCP' do
    send "/connect/12345/"
    expect(recv).to eq "/ack/12345/0/"
    send "/data/12345/0/hello\n/"
    expect(recv).to eq "/ack/12345/6/"
    expect(recv).to eq "/data/12345/0/olleh\n/"
    send "/ack/12345/6/"
    send "/data/12345/6/Hello, world!\n/"
    expect(recv).to eq "/ack/12345/20/"
    expect(recv).to eq "/data/12345/6/!dlrow ,olleH\n/"
    send "/ack/12345/20/"
    send "/close/12345/"
    expect(recv).to eq "/close/12345/"
  end
end
