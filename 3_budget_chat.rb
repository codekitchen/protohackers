#!/usr/bin/env ruby --yjit
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
    @q = Thread::Queue.new
    @users = {}
  end

  def <<(msg) = @q << msg

  def run
    loop do
      case @q.pop
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
$chat = ChatRoom.new
Thread.new { $chat.run }

def handle conn
  conn.puts 'heyo. what should we call you?'
  username = conn.gets.chomp
  unless username =~ /^[a-zA-Z0-9]{1,32}$/
    conn.puts 'what kind of name is that? bye'
    return
  end
  conn.got_username(username)
  # not remotely thread-safe, but whatevs
  if $chat.users.key?(username)
    conn.puts "nuh uh, #{username} is already here!"
    return
  end
  cb = ->(msg) { conn.puts msg rescue nil }
  $chat << [:subscribe, username, cb]
  loop do
    msg = conn.gets
    $chat << [:send, username, msg]
  end
rescue EOFError
  # bye
ensure
  $chat << [:leave, username] if cb
  conn.close
end

def server
  svr = TCPServer.new CONFIG['bind-port']
  puts "listening on #{CONFIG['bind-port']}"
  loop do
    Thread.new(svr.accept) do |sock|
      conn = $mon.connection
      conn.sock = sock
      handle conn
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
    sock.readline.tap { add_message("> #{_1}") }
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
