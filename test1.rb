require 'socket'

sock = UDPSocket.new
sock.send "/connect/12345/", 0, '127.0.0.1', 1337
p sock.recvfrom 999
sock.send "/data/12345/0/hell/", 0, '127.0.0.1', 1337
p sock.recvfrom 999
sock.send "/data/12345/0/he/", 0, '127.0.0.1', 1337
p sock.recvfrom 999
sock.send "/data/12345/4/o\n/", 0, '127.0.0.1', 1337
p sock.recvfrom 999
sleep 2
sock.send "/ack/12345/6/", 0, '127.0.0.1', 1337
p sock.recvfrom 999
sock.send "/close/12345/", 0, '127.0.0.1', 1337
p sock.recvfrom 999
p sock.recvfrom 999
p sock.recvfrom 999
p sock.recvfrom 999
p sock.recvfrom 999
