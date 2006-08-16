require File.dirname(__FILE__) + '/../test_helper'
require 'stringio'

class RequestTest < Test::Unit::TestCase
  class DummyRequest1 < ServerSide::Request::Base
    attr_reader :count, :conn
    
    def process
      @count ||= 0
      @count += 1
    end
  end

  def test_new
    r = DummyRequest1.new('hello')
    assert_equal 'hello', r.conn
    assert_equal 1, r.count
  end
  
  class DummyConnection
    attr_reader :opened
    
    def initialize
      @opened = true
    end
    
    def close
      @opened = false
    end
  end
  
  class DummyRequest2 < ServerSide::Request::Base
    attr_accessor :count, :persistent
    
    def parse_request
      @count ||= 0
      @count += 1
      @persistent = @count < 1000
    end
    
    def respond
    end
  end
  
  def test_process
    c = DummyConnection.new
    r = DummyRequest2.new(c)
    sleep 0.2
    assert_equal false, c.opened
    assert_equal 1000, r.count
  end
  
  class ServerSide::Request::Base 
    attr_accessor :conn, :method, :query, :version, :path, :parameters,
      :headers, :persistent
  end
  
  class DummyRequest3 < ServerSide::Request::Base
    def initialize
    end
  end
  
  def test_parse_request_invalid
    r = DummyRequest3.new
    r.conn = StringIO.new('POST /test')
    assert_nil r.parse_request
    r.conn = StringIO.new('invalid string')
    assert_nil r.parse_request
    r.conn = StringIO.new('GET HTTP/1.1')
    assert_nil r.parse_request
    r.conn = StringIO.new('GET /test http')
    assert_nil r.parse_request
    r.conn = StringIO.new('GET /test HTTP')
    assert_nil r.parse_request
    r.conn = StringIO.new('GET /test HTTP/')
    assert_nil r.parse_request
    r.conn = StringIO.new('POST /test HTTP/1.1')
    assert_nil r.parse_request
  end
  
  def test_parse_request
    r = DummyRequest3.new
    r.conn = StringIO.new("POST /test HTTP/1.1\r\n\r\n")
    assert_kind_of Hash, r.parse_request
    assert_equal :post, r.method
    assert_equal '/test', r.query
    assert_equal '1.1', r.version
    assert_equal '/test', r.path
    assert_equal({}, r.parameters)
    assert_equal({}, r.headers)
    assert_equal true, r.persistent
    
    r.conn = StringIO.new("GET /cex?q=node_state HTTP/1.1\r\n\r\n")
    assert_kind_of Hash, r.parse_request
    assert_equal :get, r.method
    assert_equal '/cex?q=node_state', r.query
    assert_equal '/cex', r.path
    assert_equal({:q => 'node_state'}, r.parameters)
    
    r.conn = StringIO.new("GET / HTTP/1.0\r\n\r\n")
    assert_kind_of Hash, r.parse_request
    assert_equal false, r.persistent

    r.conn = StringIO.new("GET / HTTP/invalid\r\n\r\n")
    assert_kind_of Hash, r.parse_request
    assert_equal 'invalid', r.version
    assert_equal false, r.persistent
    
    r.conn = StringIO.new("GET / HTTP/1.1\r\nConnection: close\r\n\r\n")
    assert_kind_of Hash, r.parse_request
    assert_equal '1.1', r.version
    assert_equal 'close', r.headers['Connection']
    assert_equal false, r.persistent
  end
end
