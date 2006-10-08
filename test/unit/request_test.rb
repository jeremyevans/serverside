require File.dirname(__FILE__) + '/../test_helper'
require 'stringio'

class RequestTest < Test::Unit::TestCase
  class DummyConnection
    attr_reader :opened
    
    def initialize
      @opened = true
    end
    
    def close
      @opened = false
    end
  end
  
  class DummyRequest2 < ServerSide::HTTP::Request
    attr_accessor :count
    
    def parse
      @count = 1
    end
    
    def respond
      @count += 1
      @persistent = @count < 2
    end
  end
  
  def test_process
    r = DummyRequest2.new(nil)
    sleep 0.2
    assert_equal false, r.process
    assert_equal 2, r.count
    assert_equal false, r.persistent
  end
  
  class DummyRequest3 < ServerSide::HTTP::Request
    attr_accessor :parse_result, :respond_result
    def parse; @parse_result; end
    def respond; @respond_result; end
  end
  
  class ServerSide::HTTP::Request
    attr_writer :socket, :persistent
  end
  
  def test_process_result
    r = DummyRequest3.new(nil)
    r.parse_result = nil
    r.persistent = true
    assert_equal nil, r.process
    r.parse_result = nil
    r.respond_result = true
    assert_equal nil, r.process
    r.parse_result = {}
    r.respond_result = nil
    r.persistent = false
    assert_equal false, r.process
    r.parse_result = {}
    r.respond_result = true
    r.persistent = true
    assert_equal true, r.process
    r.parse_result = {}
    r.persistent = 'hello'
    assert_equal 'hello', r.process
  end
  
  def test_parse_request_invalid
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new('POST /test')
    assert_nil r.parse
    r.socket = StringIO.new('invalid string')
    assert_nil r.parse
    r.socket = StringIO.new('GET HTTP/1.1')
    assert_nil r.parse
    r.socket = StringIO.new('GET /test http')
    assert_nil r.parse
    r.socket = StringIO.new('GET /test HTTP')
    assert_nil r.parse
    r.socket = StringIO.new('GET /test HTTP/')
    assert_nil r.parse
    r.socket = StringIO.new('POST /test HTTP/1.1')
    assert_nil r.parse
  end
  
  def test_parse_request
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new("POST /test HTTP/1.1\r\n\r\n")
    assert_kind_of Hash, r.parse
    assert_equal :post, r.method
    assert_equal '/test', r.path
    assert_nil r.query
    assert_equal '1.1', r.version
    assert_equal({}, r.parameters)
    assert_equal({}, r.headers)
    assert_equal({}, r.cookies)
    assert_nil r.response_cookies
    assert_equal true, r.persistent

    # trailing slash in path    
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new("POST /test/asdf/qw/?time=24%20hours HTTP/1.1\r\n\r\n")
    assert_kind_of Hash, r.parse
    assert_equal :post, r.method
    assert_equal '/test/asdf/qw', r.path
    assert_equal 'time=24%20hours', r.query
    assert_equal '1.1', r.version
    assert_equal({:time => '24 hours'}, r.parameters)
    assert_equal({}, r.headers)
    assert_equal({}, r.cookies)
    assert_nil r.response_cookies
    assert_equal true, r.persistent
    
    r.socket = StringIO.new("GET /cex?q=node_state HTTP/1.1\r\n\r\n")
    assert_kind_of Hash, r.parse
    assert_equal :get, r.method
    assert_equal '/cex', r.path
    assert_equal 'q=node_state', r.query
    assert_equal({:q => 'node_state'}, r.parameters)
    assert_equal({}, r.cookies)
    assert_nil r.response_cookies
    
    r.socket = StringIO.new("GET / HTTP/1.0\r\n\r\n")
    assert_kind_of Hash, r.parse
    assert_equal false, r.persistent
    assert_equal({}, r.cookies)
    assert_nil r.response_cookies

    r.socket = StringIO.new("GET / HTTP/invalid\r\n\r\n")
    assert_kind_of Hash, r.parse
    assert_equal 'invalid', r.version
    assert_equal false, r.persistent
    
    r.socket = StringIO.new("GET / HTTP/1.1\r\nConnection: close\r\n\r\n")
    assert_kind_of Hash, r.parse
    assert_equal '1.1', r.version
    assert_equal 'close', r.headers['Connection']
    assert_equal false, r.persistent
    
    # cookies
    r.socket = StringIO.new("GET / HTTP/1.1\r\nConnection: close\r\nCookie: abc=1342; def=7%2f4\r\n\r\n")
    assert_kind_of Hash, r.parse
    assert_equal 'abc=1342; def=7%2f4', r.headers['Cookie']
    assert_equal '1342', r.cookies[:abc]
    assert_equal '7/4', r.cookies[:def]
  end
  
  def test_send_response
    r = ServerSide::HTTP::Request.new(nil)
    # simple case
    r.socket = StringIO.new
    r.persistent = true
    r.send_response(200, 'text', 'Hello there!')
    r.socket.rewind
    assert_equal "HTTP/1.1 200\r\nDate: #{Time.now.httpdate}\r\nContent-Type: text\r\nContent-Length: 12\r\n\r\nHello there!",
      r.socket.read

    # include content-length    
    r.socket = StringIO.new
    r.persistent = true
    r.send_response(404, 'text/html', '<h1>404!</h1>', 10) # incorrect length
    r.socket.rewind
    assert_equal "HTTP/1.1 404\r\nDate: #{Time.now.httpdate}\r\nContent-Type: text/html\r\nContent-Length: 10\r\n\r\n<h1>404!</h1>",
      r.socket.read

    # headers
    r.socket = StringIO.new
    r.persistent = true
    r.send_response(404, 'text/html', '<h1>404!</h1>', nil, {'ETag' => 'xxyyzz'})
    r.socket.rewind
    assert_equal "HTTP/1.1 404\r\nDate: #{Time.now.httpdate}\r\nContent-Type: text/html\r\nETag: xxyyzz\r\nContent-Length: 13\r\n\r\n<h1>404!</h1>",
      r.socket.read

    # no body
    r.socket = StringIO.new
    r.persistent = true
    r.send_response(404, 'text/html', nil, nil, {'Set-Cookie' => 'abc=123'})
    r.socket.rewind
    assert_equal "HTTP/1.1 404\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nContent-Type: text/html\r\nSet-Cookie: abc=123\r\n\r\n",
      r.socket.read
    assert_equal false, r.persistent

    # not persistent
    r.socket = StringIO.new
    r.persistent = false
    r.send_response(200, 'text', 'Hello there!')
    r.socket.rewind
    assert_equal "HTTP/1.1 200\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nContent-Type: text\r\nContent-Length: 12\r\n\r\nHello there!",
      r.socket.read
      
    # socket error
    r.socket = nil
    r.persistent = true
    assert_nothing_raised {r.send_response(200, 'text', 'Hello there!')}
    assert_equal false, r.persistent
  end
  
  def test_stream
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new
    r.stream 'hey there'
    r.socket.rewind
    assert_equal 'hey there', r.socket.read
    
    r.socket = StringIO.new
    r.persistent = true
    r.send_response(404, 'text/html', nil, nil, {'Set-Cookie' => 'abc=123'})
    r.stream('hey there')
    r.socket.rewind
    assert_equal "HTTP/1.1 404\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nContent-Type: text/html\r\nSet-Cookie: abc=123\r\n\r\nhey there",
      r.socket.read
  end
  
  def test_redirect
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new
    r.redirect('http://mau.com/132')
    r.socket.rewind
    assert_equal "HTTP/1.1 302\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nLocation: http://mau.com/132\r\n\r\n", r.socket.read

    r.socket = StringIO.new
    r.redirect('http://www.google.com/search?q=meaning%20of%20life', true)
    r.socket.rewind
    assert_equal "HTTP/1.1 301\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nLocation: http://www.google.com/search?q=meaning%20of%20life\r\n\r\n", r.socket.read
  end
  
  def test_set_cookie
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new
    t = Time.now + 360
    r.set_cookie(:session, "ABCDEFG", t)
    assert_equal "Set-Cookie: session=ABCDEFG; path=/; expires=#{t.rfc2822}\r\n", r.response_cookies
    r.send_response(200, 'text', 'Hi!')
    r.socket.rewind
    assert_equal "HTTP/1.1 200\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nContent-Type: text\r\nSet-Cookie: session=ABCDEFG; path=/; expires=#{t.rfc2822}\r\nContent-Length: 3\r\n\r\nHi!", r.socket.read
  end
  
  def test_delete_cookie
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new
    r.delete_cookie(:session)
    assert_equal "Set-Cookie: session=; path=/; expires=#{Time.at(0).rfc2822}\r\n", r.response_cookies
    r.send_response(200, 'text', 'Hi!')
    r.socket.rewind
    assert_equal "HTTP/1.1 200\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nContent-Type: text\r\nSet-Cookie: session=; path=/; expires=#{Time.at(0).rfc2822}\r\nContent-Length: 3\r\n\r\nHi!", r.socket.read
  end
end
