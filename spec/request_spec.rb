require File.join(File.dirname(__FILE__), '../lib/serverside')
require 'stringio'

class DummyRequest2 < ServerSide::HTTP::Request
  attr_accessor :calls, :parse_result, :persistent
  
  def parse
    @calls ||= []
    @calls << :parse
    @parse_result
  end
  
  def respond
    @calls ||= []
    @calls << :respond
  end
end

context "HTTP::Request.process" do
  specify "should call parse and and short-circuit if the result is nil" do
    r = DummyRequest2.new(nil)
    r.process.should be_nil
    r.calls.should == [:parse]

    r.calls = []
    r.parse_result = false
    r.process.should be_false
    r.calls.should == [:parse]
  end
  
  specify "should follow parse with respond and return @persistent" do
    r = DummyRequest2.new(nil)
    r.parse_result = true
    r.process.should be_nil
    r.calls.should == [:parse, :respond]
    
    r.calls = []
    r.persistent = 'mau'
    r.process.should == 'mau'
    r.calls.should == [:parse, :respond]
  end
end

class ServerSide::HTTP::Request
  attr_writer :socket, :persistent, :response_headers
end

context "HTTP::Request.parse" do
  specify "should return nil for invalid requests" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new('POST /test')
    r.parse.should be_nil
    r.socket = StringIO.new('invalid string')
    r.parse.should be_nil
    r.socket = StringIO.new('GET HTTP/1.1')
    r.parse.should be_nil
    r.socket = StringIO.new('GET /test http')
    r.parse.should be_nil
    r.socket = StringIO.new('GET /test HTTP')
    r.parse.should be_nil
    r.socket = StringIO.new('GET /test HTTP/')
    r.parse.should be_nil
    r.socket = StringIO.new('POST /test HTTP/1.1')
    r.parse.should be_nil
  end
  
  specify "should parse valid requests and return request headers" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new(
      "POST /test HTTP/1.1\r\nContent-Type: text/html\r\n\r\n")
    r.parse.should be(r.headers)
    r.method.should == :post
    r.path.should == '/test'
    r.query.should be_nil
    r.version.should == '1.1'
    r.parameters.should == {}
    r.headers.should == {'Content-Type' => 'text/html'}
    r.cookies.should == {}
    r.response_cookies.should be_nil
#    r.persistent.should == true
  end
  
  specify "should correctly handle trailing slash in path" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new("POST /test/asdf/qw/ HTTP/1.1\r\n\r\n")
    r.parse.should_not be_nil
    r.path.should == '/test/asdf/qw'

    r.socket = StringIO.new(
      "POST /test/asdf/qw/?time=24%20hours HTTP/1.1\r\n\r\n")
    r.parse.should_not be_nil
    r.path.should == '/test/asdf/qw'
  end
  
  specify "should parse URL-encoded parameters" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new(
      "POST /test?q=node_history&time=24%20hours HTTP/1.1\r\n\r\n")
    r.parse.should_not be_nil
    r.parameters.size.should == 2
    r.parameters[:time].should == '24 hours'
    r.parameters[:q].should == 'node_history'
  end
  
  specify "should correctly parse the HTTP version" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new(
      "POST / HTTP/1.0\r\n\r\n")
    r.parse.should_not be_nil
    r.version.should == '1.0'
    r.socket = StringIO.new(
      "POST / HTTP/3.2\r\n\r\n")
    r.parse.should_not be_nil
    r.version.should == '3.2'
  end
  
  specify "should set @persistent correctly" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new("POST / HTTP/1.0\r\n\r\n")
    r.parse.should_not be_nil
#    r.persistent.should == false
    r.socket = StringIO.new("POST / HTTP/1.1\r\n\r\n")
    r.parse.should_not be_nil
#    r.persistent.should == true
    r.socket = StringIO.new("POST / HTTP/0.6\r\n\r\n")
    r.parse.should_not be_nil
#    r.persistent.should == false
    r.socket = StringIO.new("POST / HTTP/1.1\r\nConnection: close\r\n\r\n")
    r.parse.should_not be_nil
#    r.persistent.should == false
    r.socket = StringIO.new("POST / HTTP/1.1\r\nConnection: keep-alive\r\n\r\n")
    r.parse.should_not be_nil
#    r.persistent.should == true
  end
  
  specify "should parse cookies" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new(
      "POST / HTTP/1.0\r\nCookie: abc=1342; def=7%2f4\r\n\r\n")
    r.parse.should_not be_nil
    r.headers['Cookie'].should == 'abc=1342; def=7%2f4'
    r.cookies.size.should == 2
    r.cookies[:abc].should == '1342'
    r.cookies[:def].should == '7/4'
  end
  
  specify "should parse the post body" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new(
      "POST /?q=node_history HTTP/1.0\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 15\r\n\r\ntime=24%20hours")
    r.parse.should_not be_nil
    r.parameters.size.should == 2
    r.parameters[:q].should == 'node_history'
    r.parameters[:time].should == '24 hours'
  end
end

context "HTTP::Request.send_response" do
  specify "should format a response with status and body" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new
    r.send_response(200, 'text', 'Hello there!')
    r.socket.rewind
    r.socket.read.should == "HTTP/1.1 200\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nContent-Type: text\r\nContent-Length: 12\r\n\r\nHello there!"
  end
  
  specify "should format a response without connect-close when persistent" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new
    r.persistent = true
    r.send_response(200, 'text', 'Hello there!')
    r.socket.rewind
    r.socket.read.should == "HTTP/1.1 200\r\nDate: #{Time.now.httpdate}\r\nContent-Type: text\r\nContent-Length: 12\r\n\r\nHello there!"
  end
  
  specify "should format a response without content-length for streaming response" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new
    r.persistent = true
    r.send_response(200, 'text')
    r.socket.rewind
    r.socket.read.should == "HTTP/1.1 200\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nContent-Type: text\r\n\r\n"
    r.stream('hey there')
    r.socket.rewind
    r.socket.read.should == "HTTP/1.1 200\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nContent-Type: text\r\n\r\nhey there"
  end
  
  specify "should include response_headers and headers in the response" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new
    r.persistent = true
    r.response_headers['XXX'] = 'Test'
    r.send_response(200, 'text')
    r.socket.rewind
    r.socket.read.should == "HTTP/1.1 200\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nContent-Type: text\r\nXXX: Test\r\n\r\n"

    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new
    r.persistent = true
    r.send_response(200, 'text', nil, nil, {'YYY' => 'TTT'})
    r.socket.rewind
    r.socket.read.should == "HTTP/1.1 200\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nContent-Type: text\r\nYYY: TTT\r\n\r\n"
  end
  
  specify "should set persistent to false if exception is raised" do
#    r = ServerSide::HTTP::Request.new(nil)
#    r.persistent = true
#    proc {r.send_response(200, 'text', 'Hello there!')}.should_not_raise
#    r.persistent.should == false
  end

  specify "should include cookies in the response" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new
    t = Time.now + 360
    r.set_cookie(:session, "ABCDEFG", t)
    r.response_cookies.should == "Set-Cookie: session=ABCDEFG; path=/; expires=#{t.rfc2822}\r\n" 
    r.send_response(200, 'text', 'Hi!')
    r.socket.rewind
    r.socket.read.should == "HTTP/1.1 200\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nContent-Type: text\r\nSet-Cookie: session=ABCDEFG; path=/; expires=#{t.rfc2822}\r\nContent-Length: 3\r\n\r\nHi!" 

    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new
    r.delete_cookie(:session)
    r.response_cookies.should == "Set-Cookie: session=; path=/; expires=#{Time.at(0).rfc2822}\r\n"
    r.send_response(200, 'text', 'Hi!')
    r.socket.rewind
    r.socket.read.should == "HTTP/1.1 200\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nContent-Type: text\r\nSet-Cookie: session=; path=/; expires=#{Time.at(0).rfc2822}\r\nContent-Length: 3\r\n\r\nHi!"
  end
end

context "HTTP::Request.send_file" do
  specify "should include a disposition header in the response" do
    socket = StringIO.new
    r = ServerSide::HTTP::Request.new(socket)
    r.send_file('text', 'text/plain', :attachment)
    socket.rewind
    socket.read.should match(/Content-Disposition: attachment\r\n/)
  end
  
  specify "should use :inline as default disposition" do
    socket = StringIO.new
    r = ServerSide::HTTP::Request.new(socket)
    r.send_file('text', 'text/plain')
    socket.rewind
    socket.read.should match(/Content-Disposition: inline\r\n/)
  end
  
  specify "should include filename parameter if specified" do
    socket = StringIO.new
    r = ServerSide::HTTP::Request.new(socket)
    r.send_file('text', 'text/plain', :attachment, 'text.txt')
    socket.rewind
    socket.read.should match(/Content-Disposition: attachment; filename=text.txt\r\n/)
  end
  
  specify "should include a description header if specified" do
    socket = StringIO.new
    r = ServerSide::HTTP::Request.new(socket)
    r.send_file('text', 'text/plain', :attachment, 'text.txt')
    socket.rewind
    socket.read.should_not match(/Content-Description:\s/)

    socket = StringIO.new
    r = ServerSide::HTTP::Request.new(socket)
    r.send_file('text', 'text/plain', :attachment, 'text.txt', 'this is text.')
    socket.rewind
    socket.read.should match(/Content-Description:\sthis is text\./)
  end
end

context "HTTP::Request.redirect" do
  specify "should send a 302 response for temporary redirect" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new
    r.redirect('http://mau.com/132')
    r.socket.rewind
    r.socket.read.should == "HTTP/1.1 302\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nLocation: http://mau.com/132\r\n\r\n"
  end
  
  specify "should send a 301 response for permanent redirect" do
    r = ServerSide::HTTP::Request.new(nil)
    r.socket = StringIO.new
    r.redirect('http://mau.com/132', true)
    r.socket.rewind
    r.socket.read.should == "HTTP/1.1 301\r\nDate: #{Time.now.httpdate}\r\nConnection: close\r\nLocation: http://mau.com/132\r\n\r\n"
  end
end
