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

context "Caching#disable_caching" do
  specify "should set the Cache-Control header to no-cache" do
    r = DummyRequest.new
    r.response_headers['Cache-Control'].should_be_nil
    r.disable_caching
    r.response_headers['Cache-Control'].should_equal 'no-cache'
  end
  
  specify "should remove all other cache-related headers" do
    r = DummyRequest.new
    r.response_headers['ETag'] = 'something'
    r.response_headers['Vary'] = 'something'
    r.response_headers['Expires'] = 'something'
    r.response_headers['Last-Modified'] = 'something'
    r.disable_caching
    r.response_headers['ETag'].should_be_nil
    r.response_headers['Vary'].should_be_nil
    r.response_headers['Expires'].should_be_nil
    r.response_headers['Last-Modified'].should_be_nil
  end
end

context "Caching#etag_validators" do
  specify "should return an empty array if no validators are present" do
    r = DummyRequest.new
    r.etag_validators.should_equal []    
  end
  
  specify "should return an array containing all etag validators" do
    r = DummyRequest.new
    r.headers['If-None-Match'] = '"aaa-bbb"'
    r.etag_validators.should_equal ['aaa-bbb']

    r.headers['If-None-Match'] = '"aaa-bbb", "ccc-ddd"'
    r.etag_validators.should_equal ['aaa-bbb', 'ccc-ddd']
  end
  
  specify "should handle etags with and without quotes" do
    r = DummyRequest.new
    r.headers['If-None-Match'] = 'aaa-bbb'
    r.etag_validators.should_equal ['aaa-bbb']

    r.headers['If-None-Match'] = 'aaa-bbb, "ccc-ddd"'
    r.etag_validators.should_equal ['aaa-bbb', 'ccc-ddd']
  end
  
  specify "should handle a wildcard validator" do
    r = DummyRequest.new
    r.headers['If-None-Match'] = '*'
    r.etag_validators.should_equal ['*']
  end
end

context "Caching#valid_etag?" do
  specify "should return nil if no validator matches the specified etag" do
    r = DummyRequest.new
    r.valid_etag?('xxx-yyy').should_be_nil
    
    r.headers['If-None-Match'] = 'xx-yy, aaa-bbb'
    r.valid_etag?('xxx-yyy').should_be_nil
  end

  specify "should return true if a validator matches the specifed etag" do
    r = DummyRequest.new
    
    r.headers['If-None-Match'] = 'xxx-yyy'
    r.valid_etag?('xxx-yyy').should_be true
    
    r.headers['If-None-Match'] = '"xxx-yyy"'
    r.valid_etag?('xxx-yyy').should_be true
    
    r.headers['If-None-Match'] = 'aaa-bbb, xxx-yyy'
    r.valid_etag?('xxx-yyy').should_be true

    r.headers['If-None-Match'] = 'xxx-yyy, aaa-bbb'
    r.valid_etag?('xxx-yyy').should_be true
  end
  
  specify "should return true if a wildcard is included in If-None-Match" do
    r = DummyRequest.new
    
    r.headers['If-None-Match'] = '*'
    r.valid_etag?('xxx-yyy').should_be true
    
    r.headers['If-None-Match'] = 'aaa-bbb, *'
    r.valid_etag?('xxx-yyy').should_be true
  end
end

__END__


context "Caching::validate_cache" do
  specify "should set etag, last-modified and expires response headers" do
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
    resp.should_match /Expires: #{(t + 240).httpdate}\r\n/
  end
  
  specify "should include an appropriate cache-control header" do
    r = DummyRequest.new
    t = Time.now
    r.send_not_modified('dddd', t.httpdate, 240, :public)
    r.socket.rewind
    resp = r.socket.read
    resp.should_match /Cache-Control: public\r\n/

    r.socket.rewind
    r.send_not_modified('dddd', t.httpdate, 240, :private)
    r.socket.rewind
    resp = r.socket.read
    resp.should_match /Cache-Control: private\r\n/
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

context "Caching::cache_etags" do
  specify "should return an empty array if no If-None-Match header is included" do
    r = DummyRequest.new
    r.cache_etags.should_be_a_kind_of Array
    r.cache_etags.should_equal []
  end
  
  specify "should return all etags included in the If-None-Match header" do
    r = DummyRequest.new
    r.headers['If-None-Match'] = '*'
    r.cache_etags.should_equal ['*']
    r.headers['If-None-Match'] = '*, "XXX-YYY","AAA-BBB"'
    r.cache_etags.should_equal ['*', 'XXX-YYY', 'AAA-BBB']
    r.headers['If-None-Match'] = '"abcd-EFGH"'
    r.cache_etags.should_equal ['abcd-EFGH']
  end
end

context "Caching::cache_stamps" do
  specify "should return nil if no If-Modified-Since header is included" do
    r = DummyRequest.new
    r.cache_stamp.should_be_nil
  end
  
  specify "should return nil if no an invalid stamp is specified" do
    r = DummyRequest.new
    r.headers['If-Modified-Since'] = 'invalid stamp'
    r.cache_stamp.should_be_nil
  end
  
  specify "should return the stamp specified in the If-Modified-Since header" do
    r = DummyRequest.new
    t = Time.now
    r.headers['If-Modified-Since'] = t.httpdate
    r.cache_stamp.to_i.should_equal t.to_i
  end
end
