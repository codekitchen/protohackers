#!/usr/bin/env ruby --yjit
require 'socket'

require_relative 'lib/config'
require_relative 'lib/filesystem'

class Handler
  def initialize(fs=nil)
    @fs = fs || Filesystem.new
  end

  def process conn
    msg = (conn.gets || '').chomp
    args = msg.split
    cmd = args.shift
    case cmd&.upcase
    when 'HELP'
      conn.puts "OK usage: HELP|GET|PUT|LIST"
    when 'LIST'
      files = @fs.list args.shift
      conn.puts "OK #{files.size}"
      files.each { |f|
        if f.dir?
          conn.puts "#{f.name}/ DIR"
        else
          conn.puts "#{f.name} r#{f.revisions.size}"
        end
      }
    when 'PUT'
      fname = args.shift
      size = Integer(args.shift)
      raise "bad file size" unless (0..).include?(size)
      rev = @fs.write_version fname, conn.read(size)
      conn.puts "OK r#{rev}"
    when 'GET'
      fname = args.shift
      rev = args.shift # or nil
      rev = Integer(rev.sub(/^r/,'')) if rev
      contents = @fs.read fname, rev
      conn.puts "OK #{contents.length}"
      conn.write contents
    else
      conn.puts "ERR illegal method: #{cmd}"
      conn.close
    end
  rescue Filesystem::Error => e
    conn.puts "ERR #{e.message}"
  end
end
$handler = Handler.new

def handle conn
  loop do
    conn.puts 'READY'
    $handler.process(conn)
  end
rescue EOFError, IOError, Errno::EPIPE, Errno::ECONNRESET
  # bye
rescue => e
  puts e.inspect
  conn.puts "ERR what did you DO??"
ensure
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

Connection = Struct.new(:id,:queries,:status,:sock) do
  def initialize(*)
    super
    self.status = 'active'
    self.queries = []
  end
  def num_queries = queries.size

  def puts(msg) = sock.puts msg
  def write(str) = sock.write str
  def read(size) = sock.read size
  def gets
    sock.gets.tap { request.query = _1 }
  end

  def request
    self.queries[self.queries.size] = $mon.request(id)
  end

  def close
    self.status = 'closed'
    sock&.close
    sock = nil
  end
end
Request = Struct.new(:connid,:reqid,:query)

require 'glimmer-dsl-libui'

class Monitoring
  include Glimmer
  attr_accessor :conns, :dummy

  def initialize
    @lock = Mutex.new
    @conns = []
    @dummy = []
    @queries = []
    Glimmer::LibUI.timer(0.1) { @conn_table&.cell_rows = self.conns }
  end
  def sync(&) = @lock.synchronize(&)

  def connection = sync { @conns[@conns.size] = Connection[@conns.size+1] }
  def request(connid) = sync { @queries[@queries.size] = Request[connid,@queries.size+1] }

  def launch
    window('Prime Time', 1200, 600) {
      margined true
      vertical_box {
        @conn_table = table {
          text_column 'id'
          text_column 'num queries'
          text_column 'status'
          cell_rows self.conns
          on_selection_changed { |t,s|
            if s
              @requests_table.cell_rows = @conns[s].queries
            else
              @requests_table.cell_rows = []
            end
          }
        }
        @requests_table = table {
          text_column 'connid'
          text_column 'reqid'
          text_column 'query'
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
