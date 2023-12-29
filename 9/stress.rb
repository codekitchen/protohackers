require 'async'
require 'socket'
require 'oj'
Oj.mimic_JSON()

Q = %w[q1 q2 q3 q4]

LOOPS = 6
CLIENTS = 100
INSERTS_PER = 500

LOOPS.times do |i|
  puts "loop #{i}"
  Sync do
    CLIENTS.times.map do
      Async do
        sock = TCPSocket.open 'localhost', 1337
        INSERTS_PER.times do
          sock.puts({request: 'put', queue: Q.sample, pri: rand(1..5000), job: {simple: "test"}}.to_json)
          sock.gets
        end
        ids = []
        INSERTS_PER.times do
          sock.puts({request: 'get', queues: Q, wait: true}.to_json)
          ids << JSON.parse(sock.gets)['id']
        end
        ids.each { |id| sock.puts({request: 'delete', id:}.to_json) }
      end
    end.map(&:wait)
  end
end
