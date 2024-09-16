#!/usr/bin/env ruby --yjit
require_relative 'lib/config'
require 'async/queue'
require 'timeout'

Packet = Data.define(:type, :sid, :pos, :len, :dat, :sockaddr) do
  MAX_INT = 2**31-1
  class ParseError < StandardError; end
  Parser = Regexp.union(
    %r{\A/(?<type>connect)/(?<sid>\d+)/\z},
    %r{\A/(?<type>data)/(?<sid>\d+)/(?<pos>\d+)/(?<dat>(?:\\\\|\\/|[^/\\])*)/\z}m,
    %r{\A/(?<type>ack)/(?<sid>\d+)/(?<len>\d+)/\z},
    %r{\A/(?<type>close)/(?<sid>\d+)/\z},
  )
  def self.parse(str, sockaddr)
    md = Parser.match(str)
    return unless md
    Packet[sockaddr:, **md.deconstruct_keys(nil)]
  rescue ParseError
    nil
  end

  def to_s
    ["", type, sid, pos, len, dat && escape(dat), ""].compact.join("/")
  end

  def with(**args) = super(**{pos:nil,len:nil,dat:nil}.merge(args))

  def initialize(type:, sid:, sockaddr:, pos:nil, len:nil, dat:nil)
    sid = int sid
    pos &&= int pos
    len &&= int len
    dat &&= unescape dat
    super(type:, sid:, pos:, len:, dat:, sockaddr:)
  end

  def with_data(dat, pos)
    dat = escape dat
    parts = []
    until dat.empty?
      part = escape_aware_slice(dat, MAX_SEND)
      parts << with(type: 'data', pos:, dat:part)
      dat = dat[part.length..]
      pos += part.length
    end
    parts
  end

  MAX_SEND = 500
  def escape_aware_slice(str, len)
    %r{\A(?:\\.|[^\\])*}m.match(str[0,len])[0]
  end
  def int(str)
    val = Integer(str.to_i)
    raise(ParseError, "int OOB #{str.inspect}") if val > MAX_INT
    val
  end
  def unescape(str) = str.gsub(%r{\\(\\|/)}, '\1')
  def escape(str) = str.gsub(%r{(\\|/)}) {"\\#{_1}"}
end

Session = Struct.new(:sid, :packet, :q, :read_pos, :write_pos, :write_buf_pos, :write_buf) do
  RETRANSMIT_TIMEOUT = 0.5
  SESSION_TIMEOUT = 40

  def initialize(packet)
    super(packet.sid, packet, Async::Queue.new, 0, 0, 0, "")
  end
  def <<(msg) = self.q << msg

  def run(mainq)
    r,w = IO.pipe
    Async { loop { self.q << { app: r.gets.chomp.reverse+"\n" } } }
    last_message = Time.now

    loop do
      msg = Timeout.timeout(RETRANSMIT_TIMEOUT) { self.q.dequeue }
      # raise "whoops"
      last_message = Time.now
      case msg
      in type: 'connect'
        mainq << { write: packet.with(type: 'ack', len: 0) }
      in type: 'data', sid:, pos:, dat:
        if pos > read_pos
          mainq << { write: packet.with(type: 'ack', len: read_pos) }
        else
          if pos < read_pos
            diff = read_pos - pos
            pos = read_pos
            dat = dat[diff..] || ""
          end
          self.read_pos = pos+dat.length
          mainq << { write: packet.with(type: 'ack', len: read_pos) }
          w.write dat
        end
      in type: 'ack', len:
        if len > write_pos
          mainq << packet.with(type: 'close')
        else
          to_consume = len - write_buf_pos
          if to_consume > 0
            self.write_buf_pos += to_consume
            self.write_buf = self.write_buf[to_consume..]
          end
        end
      in app: dat
        pos = write_pos
        self.write_buf += dat
        self.write_pos += dat.length
        packet.with_data(dat, pos).each { mainq << { write: _1 } }
      in close: true
        break
      end
    rescue Timeout::Error
      if Time.now - last_message > SESSION_TIMEOUT
        log "session #{sid} expired, closing"
        mainq << packet.with(type: 'close')
      elsif !write_buf.empty?
        # re-send data
        packet.with_data(write_buf, write_buf_pos).each { mainq << { write: _1 } }
      end
    end
  end
end

def receiver(sock, q)
  loop do
    sock.recvfrom(1000) => dat, [_, port, addr, _]
    log "<-- #{dat}"
    msg = Packet.parse(dat, [addr, port])
    next unless msg # ignore invalid messages
    q << msg
  end
end

def sender(sock)
  sendq = Async::Queue.new
  Async do
    sendq.each do |packet|
      dat = packet.to_s
      log "--> #{dat}"
      sock.send dat, 0, *packet.sockaddr
    end
  end
  sendq
end

# alias async_orig Async
# def Async(...)
#   async_orig(...)
# end

def log(str) = puts "#{Time.now.strftime "%H:%M:%S"} #{str.inspect}"

q = Async::Queue.new
sock = UDPSocket.new
sock.bind('0.0.0.0', CONFIG['bind-port'])
puts "listening on #{CONFIG['bind-port']}"
sessions = {}
Sync do
  Async { receiver sock, q }
  sendq = sender sock

  q.each do |msg|
    case msg
    in { type: 'connect' } => packet
      ses = sessions[packet.sid]
      if !ses
        ses = sessions[packet.sid] = Session[packet]
        Async { ses.run q }
      end
      ses << msg
    in { type: 'data'|'ack' } => packet
      ses = sessions[packet.sid]
      if ses
        ses << msg
      else
        q << packet.with(type: 'close')
      end
    in { type: 'close' } => packet
      ses = sessions.delete(packet.sid)
      ses << { close: true } if ses
      # reply with close even if no session found
      sendq << packet
    in write: packet
      sendq << packet
    end
  end
end
