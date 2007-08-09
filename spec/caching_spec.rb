__END__

require File.join(File.dirname(__FILE__), '../lib/serverside')
require 'stringio'
include ServerSide::HTTP

class DummyRequest < Request
  attr_accessor :socket, :persistent
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
    r.response_headers['Cache-Control'].should == 'no-cache'
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
    r.etag_validators.should == []    
  end
  
  specify "should return an array containing all etag validators" do
    r = DummyRequest.new
    r.headers['If-None-Match'] = '"aaa-bbb"'
    r.etag_validators.should == ['aaa-bbb']

    r.headers['If-None-Match'] = '"aaa-bbb", "ccc-ddd"'
    r.etag_validators.should == ['aaa-bbb', 'ccc-ddd']
  end
  
  specify "should handle etags with and without quotes" do
    r = DummyRequest.new
    r.headers['If-None-Match'] = 'aaa-bbb'
    r.etag_validators.should == ['aaa-bbb']

    r.headers['If-None-Match'] = 'aaa-bbb, "ccc-ddd"'
    r.etag_validators.should == ['aaa-bbb', 'ccc-ddd']
  end
  
  specify "should handle a wildcard validator" do
    r = DummyRequest.new
    r.headers['If-None-Match'] = '*'
    r.etag_validators.should == ['*']
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

context "Caching#valid_etag? in expiry etag mode (no etag specified)" do
  specify "should return nil if no etag validator is included" do
    r = DummyRequest.new
    r.valid_etag?.should_be_nil
  end
  
  specify "should return true if If-None-Match includes a wildcard" do
    r = DummyRequest.new
    
    r.headers['If-None-Match'] = '*'
    r.valid_etag?.should_be true
  end
  
  specify "should ignore validators not formatted as expiry etags" do
    r = DummyRequest.new
    
    r.headers['If-None-Match'] = 'abcd'
    r.valid_etag?.should_be_nil

    r.headers['If-None-Match'] = 'xxx-yyy, zzz-zzz'
    r.valid_etag?.should_be_nil
  end
  
  specify "should parse expiry etags and check the expiration stamp" do
    r = DummyRequest.new
    t = Time.now
    fmt = Caching::EXPIRY_ETAG_FORMAT
    
    r.headers['If-None-Match'] = fmt % [t.to_i, (t - 20).to_i]
    r.valid_etag?.should_be_nil

    r.headers['If-None-Match'] = fmt % [t.to_i, (t + 20).to_i]
    r.valid_etag?.should_be true
    
    r.headers['If-None-Match'] = "xxx-yyy, #{fmt % [t.to_i, (t + 20).to_i]}, #{fmt % [t.to_i, (t - 20).to_i]}"
    r.valid_etag?.should_be true
  end
end

context "Caching#expiry_etag" do
  specify "should return an expiry etag with the stamp and expiration time" do
    r = DummyRequest.new
    
    t = Time.now
    fmt = Caching::EXPIRY_ETAG_FORMAT
    max_age = 54321
    
    r.expiry_etag(t, max_age).should == (fmt % [t.to_i, (t + max_age).to_i]) 
  end
end

context "Caching#valid_stamp?" do
  specify "should return nil if no If-Modified-Since header is included" do
    r = DummyRequest.new
    r.valid_stamp?(Time.now).should_be_nil
  end
  
  specify "should return nil if the If-Modified-Since header is different than the specified stamp" do
    t = Time.now
    r = DummyRequest.new
    r.headers['If-Modified-Since'] = t.httpdate
    r.valid_stamp?(t + 1).should_be_nil
    r.valid_stamp?(t - 1).should_be_nil
  end
  
  specify "should return true if the If-Modified-Since header matches the specified stamp" do
    t = Time.now
    r = DummyRequest.new
    r.headers['If-Modified-Since'] = t.httpdate
    r.valid_stamp?(t).should_be true
  end
end

context "Caching#validate_cache" do
  specify "should return nil if no validators are present" do
    r = DummyRequest.new
    r.validate_cache(Time.now, 360).should_be_nil
  end
  
  specify "should check for a stamp validator" do
    r = DummyRequest.new
    t = Time.now
    
    r.headers['If-Modified-Since'] = t.httpdate
    r.validate_cache(t + 1, 360).should_be_nil 
    r.validate_cache(t - 1, 360).should_be_nil
    r.validate_cache(t, 360).should_be true
  end
  
  specify "should check for an etag validator" do
    r = DummyRequest.new
    t = Time.now
    etag = 'abcdef'

    r.validate_cache(t, 360, etag).should_be_nil
    r.headers['If-None-Match'] = 'aaa-bbb'
    r.validate_cache(t, 360, etag).should_be_nil
    r.headers['If-None-Match'] = "aaa-bbb, #{etag}"
    r.validate_cache(t, 360, etag).should_be true
    r.headers['If-None-Match'] = '*'
    r.validate_cache(t, 360, etag).should_be true
  end
  
  specify "should check for an expiry etag validator if etag is unspecified" do
    r = DummyRequest.new
    t = Time.now
    fmt = Caching::EXPIRY_ETAG_FORMAT
    
    r.headers['If-None-Match'] = 'aaa-bbb'
    r.validate_cache(t, 360).should_be_nil
    r.headers['If-None-Match'] = "aaa-bbb, #{fmt % [t.to_i, (t + 20).to_i]}"
    r.validate_cache(t, 360).should_be true
    r.headers['If-None-Match'] = '*'
    r.validate_cache(t, 360).should_be true
  end

  specify "should set the response headers with caching info if request did not validate" do
    r = DummyRequest.new
    t = Time.now
    r.validate_cache(t, 360, 'aaa-bbb', :public, 'Cookie')
    r.response_headers['ETag'].should == '"aaa-bbb"'
    r.response_headers['Last-Modified'].should == t.httpdate
    r.response_headers['Expires'].should == ((t + 360).httpdate)
    r.response_headers['Cache-Control'].should == :public
    r.response_headers['Vary'].should == 'Cookie'
  end
  
  specify "should set an expiry etag if no etag is specified" do
    r = DummyRequest.new
    t = Time.now
    fmt = Caching::EXPIRY_ETAG_FORMAT
    r.validate_cache(t, 360)
    r.response_headers['ETag'].should == (
      "\"#{fmt % [t.to_i, (t + 360).to_i]}\"")
  end
  
  specify "should send a 304 response if the cache validates" do
    r = DummyRequest.new
    t = Time.now
    fmt = Caching::EXPIRY_ETAG_FORMAT
    
    r.headers['If-None-Match'] = "aaa-bbb, #{fmt % [t.to_i, (t + 20).to_i]}"
    r.validate_cache(t, 360).should_be true
    r.socket.rewind
    resp = r.socket.read
    resp.should_match /^HTTP\/1.1 304 Not Modified\r\n/

    r = DummyRequest.new
    t = Time.now
    
    r.headers['If-Modified-Since'] = t.httpdate
    r.validate_cache(t, 360).should_be true
    r.socket.rewind
    resp = r.socket.read
    resp.should_match /^HTTP\/1.1 304 Not Modified\r\n/
  end
  
  specify "should not send anything if the cache doesn't validate" do
    r = DummyRequest.new
    t = Time.now
    
    r.validate_cache(t, 360).should_be_nil
    r.socket.rewind
    resp = r.socket.read
    resp.should_be_empty
  end
  
  specify "should not execute the given block if the cache validates" do
    r = DummyRequest.new
    t = Time.now
    r.headers['If-Modified-Since'] = t.httpdate
    proc {r.validate_cache(t, 360) {raise}}.should_not_raise
  end
  
  specify "should return the result of the given block if the cache doesn't validate" do
    x = nil
    l = proc {x = :executed}
    
    r = DummyRequest.new
    t = Time.now
    r.validate_cache(t, 360, &l).should == :executed
    x.should == :executed
  end
end

context "Caching#send_not_modified_response" do
  specify "should render a 304 response" do
    r = DummyRequest.new
    r.send_not_modified_response
    r.socket.rewind
    resp = r.socket.read
    resp.should_match /^HTTP\/1.1 304 Not Modified\r\n/
    resp.should_match /Content-Length: 0\r\n/
    resp.should_match /\r\n\r\n$/ # empty response body
  end
  
  specify "should exclude Connection header if persistent" do
    r = DummyRequest.new
    r.persistent = true
    r.send_not_modified_response
    r.socket.rewind
    resp = r.socket.read
    resp.should_not_match /Connection: close\r\n/
  end
  
  specify "should include Connection header if persistent" do
    r = DummyRequest.new
    r.persistent = false
    r.send_not_modified_response
    r.socket.rewind
    resp = r.socket.read
    resp.should_match /Connection: close\r\n/
  end
end

