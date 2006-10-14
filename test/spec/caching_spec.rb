require File.join(File.dirname(__FILE__), '../../lib/serverside')
require 'stringio'
include ServerSide::HTTP

class DummyRequest < Request
  attr_accessor :socket
  include Caching
  
  def initialize
    super(StringIO.new)
    @headers = {}
  end
end

context "Caching::validate_cache" do
  specify "should set etag and last-modified response headers" do
    r = DummyRequest.new
    t = Time.now
    r.validate_cache('aaaa', t) {
      r.send_response(200, 'text/plain', 'hi', nil, {'F' => 1})
    }
    r.socket.rewind
    resp = r.socket.read
    
    resp.should_match /ETag:\s"aaaa"\r\n/
    resp.should_match /Last-Modified:\s#{t.httpdate}\r\n/
    resp.should_match /F:\s1\r\n/
  end
  
  specify "should send not modified response if client includes a suitable validator" do
    r = DummyRequest.new
    t = Time.now
    r.headers['If-None-Match'] = '"bbbb"'
    r.validate_cache('bbbb', t) {raise "This should not be called"}
    r.socket.rewind
    resp = r.socket.read

    resp.should_match /^HTTP\/1.1\s304 Not Modified\r\n/
    resp.should_match /ETag:\s"bbbb"\r\n/
    resp.should_match /Last-Modified:\s#{t.httpdate}\r\n/

    r = DummyRequest.new
    t = Time.now
    r.headers['If-Modified-Since'] = t.httpdate
    r.validate_cache('cccc', t) {raise "This should not be called"}
    r.socket.rewind
    resp = r.socket.read

    resp.should_match /^HTTP\/1.1\s304 Not Modified\r\n/
    resp.should_match /ETag:\s"cccc"\r\n/
    resp.should_match /Last-Modified:\s#{t.httpdate}\r\n/
  end
end

context "Caching::send_not_modified" do
  specify "should send back a valid 304 response with headers" do
    r = DummyRequest.new
    t = Time.now
    r.send_not_modified('dddd', t.httpdate, 240)
    r.socket.rewind
    resp = r.socket.read

    resp.should_match /^HTTP\/1.1\s304 Not Modified\r\n/
    resp.should_match /ETag:\s"dddd"\r\n/
    resp.should_match /Last-Modified:\s#{t.httpdate}\r\n/
    resp.should_match /Cache-Control:\smax-age=240\r\n/
  end
end

context "Caching::valid_client_cache?" do
  specify "should check if-none-match validator for etag" do
    r = DummyRequest.new
    t = Time.now
    r.valid_client_cache?('eeee', t).should_be_nil
    r.headers['If-None-Match'] = '"abc"'
    r.valid_client_cache?('eeee', t).should_be_nil
    r.headers['If-None-Match'] = '"eeee"'
    r.valid_client_cache?('eeee', t).should_not_be_nil
    r.headers['If-None-Match'] = '"aaa", "bbb", "ccc"'
    r.valid_client_cache?('eeee', t).should_be_nil
    r.headers['If-None-Match'] = '"aaa", "eeee", "ccc"'
    r.valid_client_cache?('eeee', t).should_not_be_nil
  end
  
  specify "should check if-none-match validator for wildcard" do
    r = DummyRequest.new
    r.headers['If-None-Match'] = '*'
    r.valid_client_cache?('eeee', nil).should_not_be_nil
    r.headers['If-None-Match'] = '*, "aaaa"'
    r.valid_client_cache?('eeee', nil).should_not_be_nil
  end
  
  specify "should check if-modified-since validator for etag" do
    r = DummyRequest.new
    t = Time.now
    r.headers['If-Modified-Since'] = (t-1).httpdate
    r.valid_client_cache?('eeee', t.httpdate).should_be false
    r.headers['If-Modified-Since'] = t.httpdate
    r.valid_client_cache?('eeee', t.httpdate).should_not_be false
  end
end