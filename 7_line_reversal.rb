#!/usr/bin/env ruby --yjit
require 'socket'
require 'async'
require 'async/barrier'
require 'async/queue'
require 'yaml'
CONFIG = YAML.load_file 'config.yml'

def log(str) = !defined?(RSpec) && puts("#{Time.now.strftime "%H:%M:%S"} #{str}")

module LRCP
  # plain value class
  Packet = Data.define(:conn, :type, :sid, :pos, :len, :dat) do
    ParseError = Class.new(StandardError)
    MAX_INT = 2**31-1
    Parse = Regexp.union(
      %r{\A/(?<type>connect)/(?<sid>\d+)/\z},
      %r{\A/(?<type>data)/(?<sid>\d+)/(?<pos>\d+)/(?<dat>(?:\\\\|\\/|[^/\\])*)/\z}m,
      %r{\A/(?<type>ack)/(?<sid>\d+)/(?<len>\d+)/\z},
      %r{\A/(?<type>close)/(?<sid>\d+)/\z},
    )
    def self.parse(conn, str)
      md = Parse.match(str)
      return unless md
      Packet[conn:, **md.named_captures(symbolize_names: true)]
    rescue ParseError
      # ignore invalid messages
    end

    def reply(**args) = Packet[**{conn:,sid:}.merge(args)]

    def reply_with_data(dat, pos:, max_send:500)
      dat = escape dat
      parts = []
      until dat.empty?
        part = escape_aware_slice(dat, max_send)
        parts << reply(type: 'data', pos:, dat:part)
        dat = dat[part.length..]
        pos += unescape(part).length
      end
      parts
    end

    def escape_aware_slice(str, len)
      %r{\A(?:\\.|[^\\])*}m.match(str[0,len])[0]
    end

    def initialize(conn:, type:, sid:, pos:nil, len:nil, dat:nil)
      sid = to_i sid
      pos &&= to_i pos
      len &&= to_i len
      dat &&= unescape dat
      super
    end

    def serialize
      ["", type, sid, len, pos, dat && escape(dat), ""].compact.join("/")
    end
    def inspect = %{#<LRCP::Packet #{serialize.inspect}>}

    def to_i(str)
      val = Integer(str) rescue (raise ParseError, "invalid value for int: #{str}")
      raise ParseError, "int too large: #{str}" if val > MAX_INT
      val
    end
    def unescape(str) = str.gsub(%r{\\(\\|/)}, '\1')
    def escape(str) = str.gsub(%r{(\\|/)}) {"\\#{_1}"}
  end

  # event-based
  class Router
    attr_reader :response_queue, :create_session
    def initialize(response_queue, create_session)
      @sessions = {}
      @response_queue = response_queue
      @create_session = create_session
    end

    # receive packet from peer connection
    def recv(packet)
      case packet
      in type: 'connect'
        sess = (@sessions[packet.sid] ||= new_session(packet))
        sess << packet
      in type: 'data'|'ack'
        sess = @sessions[packet.sid]
        if sess
          sess << packet
        else
          @response_queue << packet.reply(type: 'close')
        end
      in type: 'close'
        sess = @sessions.delete(packet.sid)
        sess&.close
        # respond /close/ regardless of if session exists
        # this does mean we echo back /close/ forever if the other side does the same...
        @response_queue << packet
      end
    end

    def new_session(packet) = @create_session.(packet)
    def session_count = @sessions.size
  end

  # relies on Async
  class Session
    MAX_READ = 2**16
    RETRANSMIT_TIMEOUT = 3.0
    SESSION_TIMEOUT = 40.0

    attr_reader :app_io
    def initialize(responses, peer_packet)
      @responses = responses
      @read_pos = @write_pos = @write_buf_pos = 0
      @write_buf = ""
      @peer = peer_packet
      @io, @app_io = Socket.pair(:UNIX, :STREAM, 0)
      @q = Async::Queue.new
      @running = nil
    end
    def bytes_sent = @write_pos
    def bytes_acked = @write_buf_pos

    def run(parent=Async::Task.current, retransmit_timeout: RETRANSMIT_TIMEOUT, session_timeout: SESSION_TIMEOUT)
      @running = parent
      reader = parent.async { app_read }
      last_message_time = Time.now
      loop do
        packet = Timeout.timeout(retransmit_timeout) { @q.dequeue }
        break unless packet # nil means "close the queue"
        last_message_time = Time.now
        case packet
        in type: 'connect'
          @responses << packet.reply(type: 'ack', len: 0)
        in type: 'data', pos:, dat:
          if pos < @read_pos
            diff = @read_pos - pos
            pos = @read_pos
            dat = dat[diff..] || ""
          end
          if pos == @read_pos
            @read_pos = pos+dat.length
            @io.write dat
          end
          @responses << packet.reply(type: 'ack', len: @read_pos)
        in type: 'ack', len:
          if len > @write_pos
            @responses << packet.reply(type: 'close')
          else
            to_consume = len - @write_buf_pos
            if to_consume > 0
              @write_buf_pos += to_consume
              @write_buf = @write_buf[to_consume..]
            end
          end
        end
      rescue Timeout::Error
        if Time.now - last_message_time > session_timeout
          log "session #{@peer.sid} timed out, closing"
          @responses << @peer.reply(type: 'close')
          break
        end
        # re-send any un-acked data
        @peer.reply_with_data(@write_buf, pos:@write_buf_pos).each { @responses << _1 }
      end
    ensure
      @io.close_write
      reader&.stop
      reader&.wait
      @io.close
    end

    # receive packet from peer connection
    def <<(packet) = @q << packet
    def caught_up? = @q.empty?

    def close
      @q << nil
      @running # allow caller to wait if they want
    end

    private

    def app_read
      loop do
        dat = @io.readpartial(MAX_READ)
        pos = @write_pos
        @write_buf += dat
        @write_pos += dat.length
        @peer.reply_with_data(dat, pos:).each { @responses << _1 }
      end
    rescue EOFError
      # socket closed
    end
  end

  # coordinating class, relies on Async and does actual I/O
  class Service
    MAXRECV = 999
    attr_reader :sock, :router
    def initialize(sock:)
      @sock = sock
      @response_queue = Async::Queue.new
      @new_connections = Async::Queue.new
      @router = Router.new(@response_queue, ->p{new_session(p)})
      @barrier = Async::Barrier.new
    end

    def new_session(packet)
      sess = Session.new(@response_queue, packet)
      @new_connections << sess.app_io
      @barrier.async { sess.run }
      sess
    end

    def run(parent=Async::Task.current)
      parent.async do
        @barrier.async { receiver }
        @barrier.async { sender }
        @barrier.wait
      ensure
        @barrier.stop
      end
    end

    def receiver
      loop do
        sock.recvfrom(MAXRECV) => msg, [_, port, _, addr]
        log "<-- #{msg.inspect[1...-1]}"
        packet = Packet.parse [addr,port], msg
        next if !packet
        router.recv packet
      end
    end

    def sender
      router.response_queue.each do |packet, addr, port|
        msg = packet.serialize
        log "--> #{msg.inspect[1...-1]}"
        sock.send msg, 0, *packet.conn
      end
    end

    def accept = @new_connections.dequeue
  end
end

# the entirety of the actual application code lol
def reverser(sock)
  while line = sock.gets&.chomp
    sock.puts line.reverse
  end
end

def server(port: CONFIG['bind-port'])
  sock = UDPSocket.new
  sock.bind('0.0.0.0', port)
  log "listening on 0.0.0.0:#{port}"
  Async do
    barrier = Async::Barrier.new
    service = LRCP::Service.new(sock:)
    running = service.run
    loop do
      conn = service.accept
      barrier.async { reverser(conn) }
    end
  ensure
    running.stop
    barrier.stop
  end
end

if $0 == __FILE__
  server().wait
  # no UI for this one
end
