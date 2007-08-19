require File.join(File.dirname(__FILE__), '../lib/serverside')

include ServerSide::HTTP

class SpecHTTPServer
  include Server
  
  attr_accessor :in, :state, :request_headers, :request_header_count, 
    :request_cookies, :response_headers
  
  attr_accessor :method, :uri, :query, :http_version
  attr_accessor :params, :persistent, :content_length
  
  def initialize
    reset
  end
  
  def reset
    post_init
    @response = ''
    @closed = false
  end
  
  attr_accessor :response, :closed
  
  def send_data(data)
    @response << data
  end
  
  def close_connection_after_writing
    @closed = true
  end
  
  def handle_error(e)
    raise e
  end
end

context "An HTTP Request should be considered malformed" do
  setup do
    @server = SpecHTTPServer.new
  end
  
  specify "if the request-line size is too big" do
    l = "GET /#{'x' * (MAX_REQUEST_LINE_SIZE - 12)}"
    proc {@server.receive_data(l)}.should_not raise_error(MalformedRequestError)

    @server.reset
    l = "GET /#{'x' * MAX_REQUEST_LINE_SIZE} HTTP/1.1\r\n"
    proc {@server.receive_data(l)}.should raise_error(MalformedRequestError)
  end
  
  specify "if the request-line is malformed" do
    l = "abcde\r\n"
    proc {@server.receive_data(l)}.should raise_error(MalformedRequestError)
    
    @server.reset
    l = "GET /\r\n"
    proc {@server.receive_data(l)}.should raise_error(MalformedRequestError)

    @server.reset
    l = "GET HTTP/\r\n"
    proc {@server.receive_data(l)}.should raise_error(MalformedRequestError)
  end
  
  specify "if a query parameter name is too big" do
    l = "GET /?#{'x' * MAX_PARAMETER_NAME_SIZE}=2 HTTP/1.1\r\n"
    proc {@server.receive_data(l)}.should_not raise_error(MalformedRequestError)

    @server.reset
    l = "GET /?#{'x' * MAX_PARAMETER_NAME_SIZE + 'y'}=2 HTTP/1.1\r\n"
    proc {@server.receive_data(l)}.should raise_error(MalformedRequestError)
  end
  
  specify "if the header count is too big" do
    l = "GET / HTTP/1.1\r\n" + ("Accept: *\r\n" * (MAX_HEADER_COUNT - 1))
    proc {@server.receive_data(l)}.should_not raise_error(MalformedRequestError)

    @server.reset
    l = "GET / HTTP/1.1\r\n" + "Accept: *\r\n" * (MAX_HEADER_COUNT + 10)
    proc {@server.receive_data(l)}.should raise_error(MalformedRequestError)
  end
  
  specify "if a header is too big" do
    l = "GET / HTTP/1.1\r\nAccept: #{'x' * MAX_HEADER_SIZE}\r\n"
    proc {@server.receive_data(l)}.should raise_error(MalformedRequestError)
  end
  
  specify "if a header name is too big" do
    l = "GET / HTTP/1.1\r\n#{'x' * MAX_HEADER_NAME_SIZE}: 1\r\n"
    proc {@server.receive_data(l)}.should_not raise_error(MalformedRequestError)

    @server.reset
    l = "GET / HTTP/1.1\r\n#{'x' * MAX_HEADER_NAME_SIZE + 'y'}: 1\r\n"
    proc {@server.receive_data(l)}.should raise_error(MalformedRequestError)
  end
  
  specify "if a header is malformed" do
    l = %[GET / HTTP/1.1\r\ntest: 231\r\n]
    proc {@server.receive_data(l)}.should_not raise_error(MalformedRequestError)

    @server.reset
    l = %[GET / HTTP/1.1\r\nmitchesunu no haha\r\n]
    proc {@server.receive_data(l)}.should raise_error(MalformedRequestError)
  end
  
  specify "if it contains a malformed cookie header" do
    l = %[GET / HTTP/1.1\r\nCookie: a=b\r\n]
    proc {@server.receive_data(l)}.should_not raise_error(MalformedRequestError)

    @server.reset
    l = %[GET / HTTP/1.1\r\nCookie: zzxxcc\r\n]
    proc {@server.receive_data(l)}.should raise_error(MalformedRequestError)
  end
end

context "A server in the initial state" do
  setup do
    @server = SpecHTTPServer.new
  end
  
  specify "should initialize all header-related variables" do
    @server.request_headers = {1 => 2}
    @server.request_header_count = 20
    @server.request_cookies = {:z => :y}
    @server.response_headers = [1, 2, 3]

    @server.set_state(:state_initial)
    @server.request_headers.should == {}
    @server.request_header_count.should == 0
    @server.request_cookies.should == {}
    @server.response_headers.should == []
  end
  
  specify "should transition to state_request_line" do
    @server.set_state(:state_initial)
    @server.state.should == :state_request_line
  end
end

context "A server in the request_line state" do
  setup do
    @server = SpecHTTPServer.new
  end
  
  specify "should wait for a CRLF before parsing the request line" do
    @server.receive_data("GET ")
    @server.state.should == :state_request_line
    @server.receive_data("/ ")
    @server.state.should == :state_request_line
    @server.receive_data("HTTP/1.1")
    @server.state.should == :state_request_line
    
    @server.receive_data("\r\n")
    @server.state.should_not == :state_request_line
  end
  
  specify "should extract method, uri, query and http version from the request line" do
    @server.receive_data("GET /abc?q=z HTTP/1.1\r\n")
    @server.method.should == :get
    @server.uri.should == '/abc'
    @server.query.should == 'q=z'
    @server.http_version.should == '1.1'
  end
  
  specify "should set persistent to true if the http version is 1.1" do
    @server.receive_data("GET / HTTP/1.1\r\n")
    @server.persistent.should be_true

    @server.reset
    @server.receive_data("GET / HTTP/1.0\r\n")
    @server.persistent.should be_false
  end
  
  specify "should parse the query into params and unescape the values" do
    @server.receive_data("GET /?x=1&y=2%203 HTTP/1.1\r\n")
    @server.params.should == {:x => '1', :y => '2 3'}
  end
  
  specify "should transition to state_request_headers" do
    @server.state.should == :state_request_line
    @server.receive_data("GET / HTTP/1.1\r\n")
    @server.state.should == :state_request_headers
  end
  
  specify "should raise MalformedRequestError on invalid request line size" do
    l = "GET /#{'x' * MAX_REQUEST_LINE_SIZE} HTTP/1.1\r\n"
    proc {@server.receive_data(l)}.should \
      raise_error(MalformedRequestError)
  end
  
  specify "should raise MalformedRequestError if the request line is invalid" do
    proc {@server.receive_data("GET\r\n")}.should raise_error(MalformedRequestError)
    
    @server.reset
    proc {@server.receive_data("GET /\r\n")}.should raise_error(MalformedRequestError)

    @server.reset
    proc {@server.receive_data("GET / 1.1\r\n")}.should raise_error(MalformedRequestError)

    @server.reset
    proc {@server.receive_data("GET ?q=1 HTTP/1.1\r\n")}.should raise_error(MalformedRequestError)

    @server.reset
    proc {@server.receive_data("GET / HTTP 1.1\r\n")}.should raise_error(MalformedRequestError)
  end
end

context "A server in the request_headers state" do
  setup do
    @server = SpecHTTPServer.new
    
    m = Module.new do
      define_method(:state_response) {}
    end
    @server.extend(m)
    @server.receive_data("GET / HTTP/1.1\r\n")
  end
  
  specify "should parse each header as it arrives" do
    @server.receive_data("Accept: text/xml\r\n")
    @server.request_headers.should == {'Accept' => 'text/xml'}
    @server.request_header_count.should == 1
    
    @server.receive_data("Cookie: x=1\r\n")
    @server.request_headers.should == {'Accept' => 'text/xml', 'Cookie' => 'x=1'}
    @server.request_header_count.should == 2
  end
  
  specify "should parse the Content-Length header into content_length" do
    @server.receive_data("Content-Length: 1234\r\n")
    @server.content_length.should == 1234
  end
  
  specify "should set persistent if a Connection header is received" do
    # HTTP 1.0 mode
    @server.persistent = false
    @server.receive_data("Connection: keep-alive\r\n")
    @server.persistent.should be_true
    
    @server.reset
    @server.receive_data("GET / HTTP/1.1\r\n")
    @server.receive_data("Connection: close\r\n")
    @server.persistent.should be_false

    @server.reset
    @server.receive_data("GET / HTTP/1.1\r\n")
    @server.receive_data("Connection: xxxxzzzz\r\n")
    @server.persistent.should be_false
  end
  
  specify "Should parse the Cookie header" do
    @server.receive_data("Cookie: x=1; y=2%203\r\n")
    @server.request_cookies.should == {:x => '1', :y => '2 3'}
  end
  
  specify "should transition to stat_response once an empty line is received" do
    @server.receive_data("Connection: close\r\n")
    @server.state.should == :state_request_headers
    
    @server.receive_data("\r\n")
    @server.state.should == :state_response
  end
  
  specify "should transition to state_request_body if content-length was given" do
    @server.receive_data("Content-Length: 13\r\n\r\n")
    @server.state.should == :state_request_body
  end
  
  specify "should raise MalformedRequestError on invalid header size" do
    proc {@server.receive_data("#{'x' * MAX_HEADER_SIZE}: 13\r\n\r\n")}.should \
      raise_error(MalformedRequestError)
  end
  
  specify "should raise MalformedRequestError on malformed header" do
    proc {@server.receive_data("abc\r\n")}.should raise_error(MalformedRequestError)
  end
end

context "A persistent connection" do
  setup do
    @server = SpecHTTPServer.new

    m = Module.new do
      define_method(:handle) {raise "hi there"}
      define_method(:handle_error) {|e| send_error_response(e)}
    end
    @server.extend(m)
  end
  
  specify "should correctly handle errors while reminaining persistent" do
    @server.receive_data("GET / HTTP/1.1\r\n\r\n")
    @server.response.scan('500').should == ['500']
    
    # clear response buffer
    @server.response = ''

    @server.receive_data("GET / HTTP/1.1\r\n\r\n")
    @server.response.scan('500').should == ['500']

    # clear response buffer
    @server.response = ''

    @server.receive_data("GET / HTTP/1.1\r\n\r\n")
    @server.response.scan('500').should == ['500']
  end

  specify "should correctly handle parsing errors while reminaining persistent" do
    @server.receive_data("GET abb\r\n\r\n")
    @server.response.scan('400').should == ['400']

    # clear response buffer
    @server.response = ''

    @server.receive_data("GET / HTTP\r\n\r\n")
    @server.response.scan('400').should == ['400']

    # clear response buffer
    @server.response = ''

    @server.receive_data("GET zzz\r\n\r\n")
    @server.response.scan('400').should == ['400']
  end
end
