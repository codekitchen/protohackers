#!/usr/bin/env ruby --yjit
require 'socket'
require 'json'
require 'prime'

require_relative 'lib/config'
require_relative 'lib/event_log'
require_relative 'lib/request_id'

def prime?(num)
  return false if num.to_i != num || num < 2
  Prime.prime?(num.to_i)
end

def handle_query input
  query = JSON.parse(input) rescue {}
  if query['method'] == 'isPrime' && query['number'].is_a?(Numeric)
    JSON.generate({prime:prime?(query['number']),method:'isPrime'})
  end
end

def handle sock, connid
  log = $log.with(connid:)
  log.event status: 'active'

  loop do
    break if sock.eof?
    input = sock.readline
    reqid = ReqId.next
    log2 = log.with(reqid:)
    log2.event query: input, status: 'processing'
    response = handle_query input
    if !response
      log2.event status: 'invalid'
      log.event status: 'error'
      sock.puts 'ERR: get bent'
      break
    end
    log2.event response:, status: 'complete'
    sock.puts response
  end
  sock.close
  log.event status: 'closed'
end

def server
  svr = TCPServer.new CONFIG['bind-port']

  (1..).each do |connid|
    sock = svr.accept
    Thread.new { handle sock, connid }
  end
end

require 'glimmer-dsl-libui'

class Monitoring
  include Glimmer
  attr_accessor :conns, :queries, :filtered_queries

  Connection = Struct.new(:id,:remote,:queries,:status)
  Query = Struct.new(:connid,:reqid,:status,:query,:response)

  def initialize
    @lock = Mutex.new
    @events = []
    @conns = []
    @filtered_queries = []
    @queries = []
    Glimmer::LibUI.timer(0.1) { process_events }
  end

  def event(ev)
    @lock.synchronize { @events << ev }
  end

  def process_events
    cur = @lock.synchronize { old=@events;@events=[];old }
    incrs = Hash.new(0)
    cur.each do |ev|
      case ev
      in connid:, status:, **nil
        c = (@conns[connid-1] ||= Connection.new(connid,nil,0))
        c.status = status
      in connid:, reqid:, status:, **rest
        c = @conns[connid-1]
        r = @queries[reqid-1]
        if !r
          r = @queries[reqid-1] = Query.new(connid, reqid)
          incrs[connid] += 1
        end
        r.status = status
        r.query = rest[:query] if rest[:query]
        r.response = rest[:response] if rest[:response]
      end
    end
    incrs.each{|cid,n|@conns[cid-1].queries+=n}
  end

  def launch
    window('Prime Time', 1200, 600) {
      margined true
      vertical_box {
        @conn_table = table {
          text_column 'id'
          text_column 'remote'
          text_column 'queries'
          text_column 'status'
          cell_rows <= [self,:conns]
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
          text_column 'status'
          text_column 'query'
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
