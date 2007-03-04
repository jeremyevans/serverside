require File.join(File.dirname(__FILE__), '../lib/serverside')
require 'stringio'
require 'fileutils'

include ServerSide::HTTP

context "HTTP::Server" do
  specify "should open TCP port for listening" do
    server = Server.new('0.0.0.0', 27963, Request)
    t = Thread.new {server.start}
    sleep 0.5
    proc {TCPServer.new('0.0.0.0', 27963)}.should_raise Errno::EADDRINUSE
    t.exit
    t.alive?.should_be false
    server.listener.close
  end
  
  specify "should loop indefinitely, accepting connections" do
    server = Server.new('0.0.0.0', 27862, Request)
    t = Thread.new {server.start}
    sleep 0.2
    s = nil
    proc {10.times {s = TCPSocket.new('localhost', 27862)}}.should_not_raise
    sleep 0.2
    server.listener.close
  end
end
