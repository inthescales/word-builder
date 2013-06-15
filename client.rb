require 'socket'

s = TCPSocket.open("localhost", 2000)
s.puts("dog noun-ine\n")
out = s.gets
s.close