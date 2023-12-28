#!/usr/bin/env ruby --yjit
require 'async'
require 'socket'

require_relative 'lib/config'
require_relative 'lib/sparse_array'

def handle_query(msg, datastore, req)
  msg = msg.unpack("A1l>l>")
  req.op, req.arg1, req.arg2 = *msg
  case msg
  in "I", timestamp, price
    datastore[timestamp] = price
    nil
  in "Q", mintime, maxtime
    vals = datastore[mintime..maxtime]
    res = vals.empty? ? 0 : (vals.sum / vals.size).to_i
    req.response = res
    [res].pack("l>")
  else
    nil
  end
end

def handle sock, conn
  conn.status = 'active'
  datastore = SparseArray.new
  loop do
    break if sock.eof?
    msg = sock.read 9 # constant message size
    req = conn.request
    response = handle_query(msg, datastore, req)
    sock.write response if response
  end
  sock.close
  conn.status = 'closed'
end

def server
  Async do
    svr = TCPServer.new CONFIG['bind-port']
    loop do
      Async(svr.accept) do |_,sock|
        conn = $mon.connection
        handle sock, conn
      end
    end
  end
end

Connection = Struct.new(:id,:remote,:queries,:status) do
  def request
    self.queries += 1
    $mon.request(id)
  end
end
Request = Struct.new(:connid,:reqid,:op,:arg1,:arg2,:response)

require 'glimmer-dsl-libui'

class Monitoring
  include Glimmer
  attr_accessor :conns, :queries, :filtered_queries

  def initialize
    @lock = Mutex.new
    @events = []
    @conns = []
    @filtered_queries = []
    @queries = []
    Glimmer::LibUI.timer(0.1) { @conn_table&.cell_rows = self.conns }
  end
  def sync(&) = @lock.synchronize(&)

  def connection = sync { @conns[@conns.size] = Connection[@conns.size+1,nil,0] }
  def request(connid) = sync { @queries[@queries.size] = Request[connid,@queries.size+1] }

  def launch
    window('Prime Time', 1200, 600) {
      margined true
      vertical_box {
        @conn_table = table {
          text_column 'id'
          text_column 'remote'
          text_column 'queries'
          text_column 'status'
          cell_rows self.conns
          on_selection_changed { |t,s|
            if s
              connid = @conns[s].id
              self.filtered_queries = @queries.select {_1.connid==connid}
            else
              self.filtered_queries = []
            end
          }
        }
        @query_table = table {
          text_column 'connid'
          text_column 'reqid'
          text_column 'op'
          text_column 'arg1'
          text_column 'arg2'
          text_column 'response'
          cell_rows <= [self,:filtered_queries]
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
