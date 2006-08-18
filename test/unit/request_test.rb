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
    assert_equal '/test', r.path
    assert_nil r.query
    assert_equal '1.1', r.version
    assert_equal({}, r.parameters)
    assert_equal({}, r.headers)
    assert_equal true, r.persistent
    
    r.conn = StringIO.new("GET /cex?q=node_state HTTP/1.1\r\n\r\n")
    assert_kind_of Hash, r.parse_request
    assert_equal :get, r.method
    assert_equal '/cex', r.path
    assert_equal 'q=node_state', r.query
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
  
  def test_send_response
    r = DummyRequest3.new
    # simple case
    r.conn = StringIO.new
    r.persistent = true
    r.send_response(200, 'text', 'Hello there!')
    r.conn.rewind
    assert_equal "HTTP/1.1 200\r\nContent-Type: text\r\nContent-Length: 12\r\n\r\nHello there!",
      r.conn.read

    # include content-length    
    r.conn = StringIO.new
    r.persistent = true
    r.send_response(404, 'text/html', '<h1>404!</h1>', 10) # incorrect length
    r.conn.rewind
    assert_equal "HTTP/1.1 404\r\nContent-Type: text/html\r\nContent-Length: 10\r\n\r\n<h1>404!</h1>",
      r.conn.read

    # headers
    r.conn = StringIO.new
    r.persistent = true
    r.send_response(404, 'text/html', '<h1>404!</h1>', nil, {'ETag' => 'xxyyzz'})
    r.conn.rewind
    assert_equal "HTTP/1.1 404\r\nContent-Type: text/html\r\nETag: xxyyzz\r\nContent-Length: 13\r\n\r\n<h1>404!</h1>",
      r.conn.read

    # no body
    r.conn = StringIO.new
    r.persistent = true
    r.send_response(404, 'text/html', nil, nil, {'Set-Cookie' => 'abc=123'})
    r.conn.rewind
    assert_equal "HTTP/1.1 404\r\nConnection: close\r\nContent-Type: text/html\r\nSet-Cookie: abc=123\r\n\r\n",
      r.conn.read
    assert_equal false, r.persistent

    # not persistent
    r.conn = StringIO.new
    r.persistent = false
    r.send_response(200, 'text', 'Hello there!')
    r.conn.rewind
    assert_equal "HTTP/1.1 200\r\nConnection: close\r\nContent-Type: text\r\nContent-Length: 12\r\n\r\nHello there!",
      r.conn.read
      
    # socket error
    r.conn = nil
    r.persistent = true
    assert_nothing_raised {r.send_response(200, 'text', 'Hello there!')}
    assert_equal false, r.persistent
  end
  
  def test_stream
    r = DummyRequest3.new
    r.conn = StringIO.new
    r.stream 'hey there'
    r.conn.rewind
    assert_equal 'hey there', r.conn.read
    
    r.conn = StringIO.new
    r.persistent = true
    r.send_response(404, 'text/html', nil, nil, {'Set-Cookie' => 'abc=123'})
    r.stream('hey there')
    r.conn.rewind
    assert_equal "HTTP/1.1 404\r\nConnection: close\r\nContent-Type: text/html\r\nSet-Cookie: abc=123\r\n\r\nhey there",
      r.conn.read
  end
end
