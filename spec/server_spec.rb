require File.join(File.dirname(__FILE__), '../lib/serverside')
require 'stringio'
require 'fileutils'

include ServerSide::HTTP

$http_connection_created = false

class Connection
  alias_method :orig_initialize, :initialize
  def initialize(socket, request_class)
    orig_initialize(socket, request_class)
    if (request_class == ServerSide::HTTP::Request) && socket.is_a?(TCPSocket)
      $http_connection_created = true
    end
  end
end

context "HTTP::Server" do
  specify "should open TCP port for listening" do
    server = Server.new('0.0.0.0', 17863, Request)
    t = Thread.new {server.start}
    proc {TCPServer.new('0.0.0.0', 17863)}.should_raise Errno::EADDRINUSE
    t.exit
    t.alive?.should_be false
    server.listener.close
  end
  
  specify "should loop indefinitely, accepting connections" do
    $http_connection_created = false
    server = Server.new('0.0.0.0', 17863, Request)
    t = Thread.new {server.start}
    sleep 0.2
    s = nil
    proc {s = TCPSocket.new('localhost', 17863)}.should_not_raise
    sleep 0.2
    $http_connection_created.should == true
    server.listener.close
  end
end
