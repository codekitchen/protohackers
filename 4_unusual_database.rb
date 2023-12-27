#!/usr/bin/env ruby --yjit
require 'socket'

require_relative 'lib/config'

MAXSIZE = 1000

def server
  db = { 'version'=>'ultra store 🤘 v1.0' }
  sock = UDPSocket.new
  sock.bind('0.0.0.0', CONFIG['bind-port'])
  puts "listening on #{CONFIG['bind-port']}"
  loop do
    sock.recvfrom(MAXSIZE) => msg, [_, port, addr, _]
    puts "got '#{msg}' from #{port} #{addr}"
    key, value = msg.split("=", 2)
    key ||= ''
    if value
      db[key] = value unless key == 'version'
    else
      res = "#{key}=#{db[key]}"
      puts "replying #{res}"
      sock.send(res, 0, addr, port)
    end
  end
end

if $0 == __FILE__
  # no UI for this one
  server
end
