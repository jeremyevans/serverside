require File.dirname(__FILE__) + '/../test_helper'
require 'stringio'

class ConnectionTest < Test::Unit::TestCase
  class ServerSide::HTTP::Connection
    attr_reader :conn, :request_class, :thread
  end
  
  class DummyRequest1 < ServerSide::HTTP::Request
    @@instance_count = 0
    
    def initialize(conn)
      @@instance_count += 1
      super(conn)
    end
    
    def self.instance_count
      @@instance_count
    end
    
    def process
      @conn[:count] ||= 0
      @conn[:count] += 1
      @conn[:count] < 1000
    end
  end
  
  class DummyConn < Hash
    attr_accessor :closed
    def close; @closed = true; end
  end

  def test_new
    r = ServerSide::HTTP::Connection.new('hello', ServerSide::HTTP::Request)
    sleep 0.1
    assert_equal 'hello', r.conn
    assert_equal ServerSide::HTTP::Request, r.request_class
    assert_equal false, r.thread.alive?
    
    c = DummyConn.new
    r = ServerSide::HTTP::Connection.new(c, DummyRequest1)
    assert_equal DummyRequest1, r.request_class
    r.thread.join
    assert_equal 1000, c[:count]
    assert_equal 1000, DummyRequest1.instance_count
    assert_equal true, c.closed
  end
end
