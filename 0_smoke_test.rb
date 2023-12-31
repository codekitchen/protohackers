#!/usr/bin/env ruby --yjit
require 'async'
require 'socket'
require 'yaml'
CONFIG = YAML.load_file 'config.yml'
port = CONFIG['bind-port']

def handle conn
  puts "accepted connection #{conn.inspect}"
  until conn.eof?
    dat = conn.readpartial(1024)
    conn.write dat
  end
  conn.close
  puts "connection closed"
end

Async do
  svr = TCPServer.new port

  loop do
    s = svr.accept
    Async { handle s }
  end
end
