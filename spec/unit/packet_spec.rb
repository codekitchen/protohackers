require_relative '../../7_line_reversal'

module LRCP
  RSpec.describe Packet do
    context 'parsing' do
      let(:conn) { :stub_connection }

      describe 'a /connect/ message' do
        it 'parses' do
          packet = Packet.parse(conn, "/connect/12345/")
          expect(packet).to have_attributes(
            conn:,
            type: 'connect',
            sid: 12345,
          )
        end

        it 'serializes' do
          packet = Packet.parse(conn, "/connect/12345/")
          expect(packet.serialize).to eq "/connect/12345/"
        end

        it 'rejects too-large session ids' do
          packet = Packet.parse(conn, "/connect/#{2**31}/")
          expect(packet).to be_nil
        end
      end

      describe 'a /data/ message' do
        let(:packet) { Packet.parse(conn, "/data/12345/0/hello\\/there/") }
        it 'unescapes the data on parse' do
          expect(packet.dat).to eq "hello/there"
        end

        it 'escapes the data on serialize' do
          expect(packet.serialize).to eq "/data/12345/0/hello\\/there/"
        end
      end

      describe '#reply_with_data' do
        it 'splits too-large data into multiple packets' do
          packet = Packet.parse(conn, "/connect/12345/")
          res = packet.reply_with_data("hi/"*5, pos: 5, max_send: 4)
          expect(res.map(&:serialize)).to eq([
            "/data/12345/5/hi\\//",
            "/data/12345/8/hi\\//",
            "/data/12345/11/hi\\//",
            "/data/12345/14/hi\\//",
            "/data/12345/17/hi\\//",
          ])
        end
      end
    end
  end
end
