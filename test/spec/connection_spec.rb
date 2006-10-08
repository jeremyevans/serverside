require File.join(File.dirname(__FILE__), '../../lib/serverside')

# String extensions

class ServerSide::HTTP::Connection
  attr_reader :socket, :request_class, :thread
end

$pause_request = false

class DummyRequest1 < ServerSide::HTTP::Request
  @@instance_count = 0
  
  def initialize(socket)
    @@instance_count += 1
    super(socket)
  end
  
  def self.instance_count
    @@instance_count
  end
  
  def process
    sleep 0.1 while $pause_request
  
    @socket[:count] ||= 0
    @socket[:count] += 1
    @socket[:count] < 1000
  end
end

class DummySocket < Hash
  attr_accessor :closed
  def close; @closed = true; end
end

include ServerSide::HTTP

context "Connection.initialize" do
  specify "should take two parameters: socket and request_class" do
    proc {Connection.new}.should_raise ArgumentError
    proc {Connection.new(nil)}.should_raise ArgumentError
    s = 'socket'
    r = 'request_class'
    c = Connection.new(s, r)
    c.socket.should_be s
    c.request_class.should_be r
  end
  
  specify "should spawn a thread that invokes Connection.process" do
    $pause_request = true
    c = Connection.new(DummySocket.new, DummyRequest1)
    c.thread.should_be_an_instance_of Thread
    c.thread.alive?.should_equal true
    DummyRequest1.instance_count.should_equal 1
    $pause_request = false
    sleep 0.1 while c.thread.alive?
    DummyRequest1.instance_count.should_equal 1000
  end
end

