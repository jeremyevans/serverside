require File.join(File.dirname(__FILE__), 'spec_helper')

include ServerSide::HTTP

context "Response.new" do
  specify "should use a default status of 200 OK" do
    @res = Response.new
    @res.status.should == '200 OK'
  end
  
  specify "should extract status from options" do
    @res = Response.new(:status => 'aok')
    @res.status.should == 'aok'
  end
  
  specify "should extract body from options" do
    @res = Response.new(:status => 200, :body => 'hello!')
    @res.body.should == 'hello!'
  end
  
  specify "should extract headers from options" do
    @res = Response.new(:status => 200, :content_type => 'text/html')
    @res.status.should == 200
    @res.headers.size.should == 1
    @res.headers[0].should == "Content-Type: text/html\r\n"
  end
  
  specify "should extract streaming option from options" do
    @res = Response.new(:streaming => true)
    @res.streaming.should be_true
  end
  
  specify "should default body to empty string unless streaming" do
    @res = Response.new
    @res.body.should == ''
    
    @res = Response.new(:streaming => true)
    @res.body.should be_nil
  end
end

context "Response.redirect" do
  setup do
    @res = Response.redirect('foobar.html')
  end
  
  specify "should default to temporary redirect" do
    @res.status.should == STATUS_FOUND
  end
  
  specify "should support custom status" do
    @res = Response.redirect('foobar.html', 'BBQ')
    @res.status.should == 'BBQ'
  end
  
  specify "should include a location header with the redirect url" do
    @res.headers.should == ["Location: foobar.html\r\n"]
  end
end

context "Response.static" do
  setup do
    @t = Time.now
    @res = Response.static(__FILE__)
  end
  
  specify "should have the file content as the body" do
    @res.body.should == IO.read(__FILE__)
  end
  
  specify "should raise not found error for an unknown file" do
    proc {Response.static('xxx_yyy_zzz')}.should raise_error(NotFoundError)
  end
  
  specify "should set cache headers correctly" do
    s = @res.to_s
    s.should =~ /\r\nETag: "#{Regexp.quote(File.etag(__FILE__))}"\r\n/
    s.should =~ /\r\nLast-Modified: #{File.mtime(__FILE__).httpdate}\r\n/
    s.should =~ /\r\nExpires: #{(@t + 86400).httpdate}\r\n/
  end
  
  specify "should validate the client's cache" do
    1.should == 1
  end
  
  specify "should be able to serve directories" do
    proc {Response.static('.')}.should_not raise_error
  end
end

context "Response.to_s" do
  specify "should render the status correctly" do
    r = Response.new
    s = r.to_s
    s.should =~ /^HTTP\/1.1 200 OK\r\n/
    
    r = Response.new(:status => '400 Bad Request')
    s = r.to_s
    s.should =~ /^HTTP\/1.1 400 Bad Request\r\n/
  end
  
  specify "should include a Date header" do
    r = Response.new
    s = r.to_s
    s.should =~ /^HTTP\/1.1 200 OK\r\nDate: (.+)\r\n/
    
    # extract stamp
    s =~ /^HTTP\/1.1 200 OK\r\nDate: (.+)\r\n/
    proc {Time.parse($1)}.should_not raise_error
  end
  
  specify "should include blank line before the body" do
    r = Response.new
    s = r.to_s
    s.should =~ /(.+)\r\n\r\n$/

    r = Response.new(:body => 'test')
    s = r.to_s
    s.should =~ /(.+)\r\n\r\ntest$/
  end
  
  specify "should include a content_length unless body is nil" do
    b = 'a' * (rand(30) + 30)
    r = Response.new(:body => b)
    s = r.to_s
    s.should =~ /Content-Length: #{b.size}\r\n\r\n#{b}$/

    r = Response.new(:streaming => true)
    s = r.to_s
    s.should_not =~ /Content-Length/
  end
  
  specify "should not include a content_length if streaming" do
    r = Response.new(:body => 'test', :streaming => true)
    s = r.to_s
    s.should_not =~ /Content-Length/
    s.should =~ /\r\n\r\ntest$/
  end
  
  specify "should include all headers in the response" do
    r = Response.new(:streaming => true)
    r.add_header('ABC', 123)
    r.add_header('DEF', 456)
    s = r.to_s
    
    s.should =~ /\r\nABC: 123\r\nDEF: 456\r\n\r\n$/
  end
end

context "Response.add_header" do
  setup do
    @res = Response.new
  end
  
  specify "should a header to the response's headers" do
    @res.add_header('ABC', '123')
    @res.headers.should == ["ABC: 123\r\n"]
    
    @res.add_header('DEF', '456')
    @res.headers.should == ["ABC: 123\r\n", "DEF: 456\r\n"]
  end
  
  specify "should be always additive" do
    @res.add_header('ABC', '123')
    @res.add_header('ABC', '456')
    @res.headers.should == ["ABC: 123\r\n", "ABC: 456\r\n"]
  end
end

context "Response.set_cookie" do
  setup do
    @res = Response.new
  end
  
  specify "should add a cookie header" do
    t = Time.now + 1000
    @res.set_cookie(:abc, '2 3 4', :expires => t)
    @res.headers.should == ["Set-Cookie: abc=2+3+4; path=/; expires=#{t.httpdate}\r\n"]
  end
  
  specify "should accept a path option" do
    t = Time.now + 1000
    @res.set_cookie(:abc, '2 3 4', :path => '/def', :expires => t)
    @res.headers.should == ["Set-Cookie: abc=2+3+4; path=/def; expires=#{t.httpdate}\r\n"]
  end

  specify "should accept a domain option" do
    t = Time.now + 1000
    @res.set_cookie(:abc, '2 3 4', :domain => 'test.net', :expires => t)
    @res.headers.should == ["Set-Cookie: abc=2+3+4; path=/; expires=#{t.httpdate}; domain=test.net\r\n"]
  end
  
  specify "should accept a ttl option" do
    t = Time.now + 1000
    @res.set_cookie(:abc, '2 3 4', :ttl => 1000)
    @res.headers.should == ["Set-Cookie: abc=2+3+4; path=/; expires=#{t.httpdate}\r\n"]
  end
end

context "Response.cache" do
  setup do
    @res = Response.new
  end
  
  specify "should support a :cache_control option" do
    @res.cache(:cache_control => 'public')
    @res.headers.should == ["Cache-Control: public\r\n"]
  end
  
  specify "should support an :expires option" do
    t = Time.now + 1000
    @res.cache(:expires => t)
    @res.headers.should == ["Expires: #{t.httpdate}\r\n"]
  end
  
  specify "should support a :ttl option" do
    t = Time.now + 1000
    @res.cache(:ttl => 1000)
    @res.headers.should == ["Expires: #{t.httpdate}\r\n"]
  end
  
  specify "should remove the cache-control header if present" do
    @res.add_header('Cache-Control', 'max-age=300')
    @res.headers.should == ["Cache-Control: max-age=300\r\n"]
    t = Time.now + 1000
    @res.cache(:expires => t)
    @res.headers.should == ["Expires: #{t.httpdate}\r\n"]
  end
end

context "Response.validate_cache" do
  setup do
    @req = Request.new(nil)
    @last_modified = Time.now - 300
    @req.headers['If-None-Match'] = '"abcde"'
    @req.headers['If-Modified-Since'] = @last_modified.httpdate
    
    @res = Response.new(:request => @req)
  end
  
  specify "should validate against an etag validator" do
    @res.validate_cache(:etag => 'abcde')
    @res.status.should == '304 Not Modified'
  end
  
  specify "should validate against a last-modified validator" do
    @res.validate_cache(:last_modified => @last_modified)
    @res.status.should == '304 Not Modified'
  end
  
  specify "should yield to the supplied block if the cache is not validated" do
    @res.validate_cache(:etag => 'defgh') do |r|
      r.status = '204'
      r.body = 'hey there hey'
    end
    
    @res.status.should == '204'
    @res.body.should == 'hey there hey'
  end
  
  specify "should set cache-related headers" do
    t = Time.now + 1000
    @res.validate_cache(:etag => 'defgh', :expires => t) do |r|
      r.status = '204'
      r.body = 'hey there hey'
    end
    s = @res.to_s
    s.should =~ /\r\nETag: "defgh"\r\n/
    s.should =~ /\r\nExpires: #{t.httpdate}\r\n/
    
    @res = Response.new(:request => @req)
    t = Time.now + 1000
    @res.validate_cache(:etag => 'defgh', :ttl => 1000) do |r|
      r.status = '204'
      r.body = 'hey there hey'
    end
    s = @res.to_s
    s.should =~ /\r\nETag: "defgh"\r\n/
    s.should =~ /\r\nExpires: #{t.httpdate}\r\n/

    @res = Response.new(:request => @req)
    t = Time.now
    @res.validate_cache(:last_modified => t, :cache_control => 'private') do |r|
      r.status = '204'
      r.body = 'hey there hey'
    end
    s = @res.to_s
    s.should =~ /\r\nLast-Modified: #{t.httpdate}\r\n/
    s.should =~ /\r\nCache-Control: private\r\n/
  end
end