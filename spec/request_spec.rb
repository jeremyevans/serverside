require File.join(File.dirname(__FILE__), 'spec_helper')

include ServerSide::HTTP

context "A Request" do
  setup do
    @server = SpecHTTPServer.new

    m = Module.new do
      attr_reader :req, :error
      define_method(:handle) {|req| @req = req}
      define_method(:handle_error) {|e| @error = e}
    end
    @server.extend(m)
  end
  
  MOCK_GET1 = "GET / HTTP/1.1\r\n\r\n"

  specify "should be passed to the handle request" do
    @server.receive_data(MOCK_GET1)
    
    @server.req.should be_a_kind_of(ServerSide::HTTP::Request)
  end
  
  MOCK_POST1 = "POST /abcd HTTP/1.1\r\n\r\n"

  specify "should provide the HTTP method" do
    @server.receive_data(MOCK_GET1)
    @server.request.method.should == :get

    @server.set_state(:state_initial)
    @server.receive_data(MOCK_POST1)
    @server.request.method.should == :post
  end

  MOCK_HTTP_1_0 = "GET /xxx HTTP/1.0\r\n\r\n"
  
  specify "should provide the HTTP version" do
    @server.receive_data(MOCK_GET1)
    @server.request.http_version.should == '1.1'
    @server.request.persistent.should == true
    
    @server.set_state(:state_initial)
    @server.receive_data(MOCK_HTTP_1_0)
    @server.request.http_version.should == '1.0'
    @server.request.persistent.should == false
  end
  
  specify "should provide the request line" do
    @server.receive_data(MOCK_GET1)
    @server.request.request_line.should == 'GET / HTTP/1.1'
  end
  
  MOCK_GET_PARAMS = "GET /?q=state&f=xml HTTP/1.1\r\n\r\n"
  
  specify "should provide the parameters" do
    @server.receive_data(MOCK_GET1)
    @server.request.params.should == {}

    @server.set_state(:state_initial)
    @server.receive_data(MOCK_GET_PARAMS)
    @server.request.params.should == {:q => 'state', :f => 'xml'}
  end
  
  MOCK_POST_PARAMS = "POST / HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 12\r\n\r\nq=state&f=js"

  specify "should provide parameters for POST requests with URL-encoded parameters" do
    @server.set_state(:state_initial)
    @server.receive_data(MOCK_POST_PARAMS)
    @server.request.params.should == {:q => 'state', :f => 'js'}
  end
  
  MOCK_POST_CHARSET_PARAMS = "POST / HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded; charset=UTF-8\r\nContent-Length: 12\r\n\r\nq=state&f=js"

  specify "should provide parameters for POST requests with URL-encoded parameters and charset" do
    @server.set_state(:state_initial)
    @server.receive_data(MOCK_POST_CHARSET_PARAMS)
    @server.request.content_type.should == 'application/x-www-form-urlencoded'
    @server.request.params.should == {:q => 'state', :f => 'js'}
  end

  MOCK_GET2 = "GET /xxx HTTP/1.0\r\nHost: reality-scada.net\r\n\r\n"
  MOCK_GET3 = "GET /xxx HTTP/1.0\r\nHost: abc.net:443\r\n\r\n"
  MOCK_GET4 = "GET /xxx HTTP/1.0\r\nHost: xyz.net:3321\r\n\r\n"
  
  specify "should provide the host and port" do
    @server.receive_data(MOCK_GET2)
    @server.request.host.should == 'reality-scada.net'
    @server.request.port.should be_nil
    @server.request.should_not be_encrypted

    @server.set_state(:state_initial)
    @server.receive_data(MOCK_GET3)
    @server.request.host.should == 'abc.net'
    @server.request.port.should == 443
    @server.request.should be_encrypted

    @server.set_state(:state_initial)
    @server.receive_data(MOCK_GET4)
    @server.request.host.should == 'xyz.net'
    @server.request.port.should == 3321
    @server.request.should_not be_encrypted
  end
  
  MOCK_GET5 = "GET / HTTP/1.1\r\nX-Forwarded-For: 12.33.44.55\r\n\r\n"
  
  specify "should provide the client name" do
    m = Module.new do
      def get_peername; end
    end
    @server.extend(m)
    
    @server.receive_data(MOCK_GET1)
    @server.request.client_name.should be_nil

    @server.set_state(:state_initial)
    @server.receive_data(MOCK_GET5)
    @server.request.client_name.should == '12.33.44.55'
  end
end

context "Request.accept?" do
  setup do
    @req = Request.new(nil)
  end
  
  specify "should return nil if the Accept header is not there" do
    @req.accept?(//).should be_nil
  end
  
  specify "should match the Accept header to the supplied pattern" do
    @req.headers[:accept] = 'text/html; text/plain'
    @req.accept?(/html/).should be_true
    @req.accept?(/plain/).should be_true
    @req.accept?(/^text/).should be_true
    @req.accept?(/text$/).should_not be_true
  end
  
  specify "should support String patterns as well" do
    @req.headers[:accept] = 'text/html; text/plain'
    @req.accept?('html').should be_true
    @req.accept?('plain').should be_true
    @req.accept?('xml').should_not be_true
  end
end