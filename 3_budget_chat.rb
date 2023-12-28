#!/usr/bin/env ruby --yjit
require 'async'
require 'async/queue'
require 'socket'

require_relative 'lib/config'

JOINED = [
  "* %{username} has sauntered in",
  "* %{username} has entered the room",
  "* %{username} has joined, quick stop talking about them",
  "* everybody welcome %{username}",
]

class ChatRoom
  attr_reader :users

  def initialize
    @q = Async::Queue.new
    @users = {}
  end

  def <<(msg) = @q << msg

  def run
    @q.each do |msg|
      case msg
      in [:subscribe, username, subscriber]
        join_msg = format(JOINED.sample, username:)
        @users.each { _2.(join_msg) }
        subscriber.("* already here: #{@users.keys.join(", ")}")
        @users[username] = subscriber

      in [:send, username, message]
        message = "[#{username}] #{message}"
        @users.each { |u,cb| cb.(message) unless u == username }

      in [:leave, username]
        prev = @users.delete(username)
        next unless prev
        leave_msg = "* #{username} has left the room"
        @users.each { |u,cb| cb.(leave_msg) }
      end
    end
  end
end

def handle conn, room
  conn.puts 'heyo. what should we call you?'
  username = conn.gets&.chomp
  unless username =~ /^[a-zA-Z0-9]{1,32}$/
    conn.puts 'what kind of name is that? bye'
    return
  end
  conn.got_username(username)

  # TODO: race condition
  if room.users.key?(username)
    conn.puts "nuh uh, #{username} is already here!"
    return
  end

  q = Async::Queue.new
  cb = ->(msg) { q << [room, msg] }
  room << [:subscribe, username, cb]
  # read from socket in separate task
  Async { gets_to_queue conn, q }

  q.each do |from, msg|
    case from
    in ^room
      conn.puts msg
    in ^conn
      break if !msg # connection closed
      room << [:send, username, msg]
    end
  end
ensure
  room << [:leave, username] if cb
  conn.close
end

def gets_to_queue(sock, q)
  loop do
    msg = sock.gets
    break if !msg
    q << [sock, msg]
  end
ensure
  q << [sock, nil]
end

def server
  Async do
    room = ChatRoom.new
    Async { room.run }
    svr = TCPServer.new CONFIG['bind-port']
    puts "listening on #{CONFIG['bind-port']}"
    loop do
      Async(svr.accept) do |_,sock|
        conn = $mon.connection
        conn.sock = sock
        handle conn, room
      end
    end
  end
end

Connection = Struct.new(:id,:username,:status,:messages,:sock) do
  M = Struct.new(:message)
  def initialize(*)
    super
    self.status = 'waiting for username'
    self.messages = []
  end

  def puts(msg)
    add_message msg
    sock.puts msg
  end

  def gets
    sock.gets.tap { add_message("> #{_1}") }
  end

  def add_message(msg)
    self.messages << M[msg]
  end

  def message_count = messages.size

  def got_username(username)
    self.username = username
    self.status = 'active'
  end

  def close
    self.status = 'closed'
    sock&.close
    sock = nil
  end
end

require 'glimmer-dsl-libui'

class Monitoring
  include Glimmer
  attr_accessor :conns, :dummy

  def initialize
    @lock = Mutex.new
    @conns = []
    @dummy = []
    Glimmer::LibUI.timer(0.1) { @conn_table&.cell_rows = self.conns }
  end
  def sync(&) = @lock.synchronize(&)

  def connection = sync { @conns[@conns.size] = Connection[@conns.size+1] }

  def launch
    window('Prime Time', 1200, 600) {
      margined true
      vertical_box {
        @conn_table = table {
          text_column 'id'
          text_column 'username'
          text_column 'message count'
          text_column 'status'
          cell_rows self.conns
          on_selection_changed { |t,s|
            if s
              @messages_table.cell_rows = @conns[s].messages
            else
              @messages_table.cell_rows = []
            end
          }
        }
        @messages_table = table {
          text_column 'message'
          cell_rows <= [self, :dummy]
        }
      }
    }.show
  end
end

def monitor
  $mon = Monitoring.new
  $mon.launch
end

if $0 == __FILE__
  Thread.new { server }
  monitor
end
