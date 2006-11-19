require File.join(File.dirname(__FILE__), '../lib/serverside')
require 'stringio'

class ServerSide::Router
  def self.rules
    @@rules
  end
  
  def self.reset_rules
    @@rules = []
  end
  
  attr_accessor :path
end

context "ServerSide::Controller.mount" do
  specify "should accept a routing rule as argument" do
    proc {ServerSide::Controller.mount}.should_raise ArgumentError
  end
  
  specify "should return a subclass of ServerSide::Controller" do
    c = ServerSide::Controller.mount(:path => '/test')
    c.should_be_a_kind_of Class
    c.superclass.should_be ServerSide::Controller
  end
  
  specify "should add a routing rule using ServerSide::Router.route" do
    ServerSide::Router.reset_rules
    rule = {:path => '/test'}
    c = ServerSide::Controller.mount(rule)
    sub_class = Class.new(c)
    r = ServerSide::Router.rules.first
    r.first.should == rule
    r.last.should_be_a_kind_of Proc
    c.module_eval do
      define_method(:initialize) {|req| $req = req}
    end
    res = r.last.call
    res.should_be_a_kind_of sub_class
    
    r = ServerSide::Router.new(StringIO.new)
    r.path = '/test'
    r.respond
    $req.should_be_a_kind_of ServerSide::Router
  end

  specify "should accept either an argument or block as the rule" do
    ServerSide::Router.reset_rules
    rule = {:path => '/test'}
    c = Class.new(ServerSide::Controller.mount(rule))
    r = ServerSide::Router.rules.first
    r.first.should_be rule

    ServerSide::Router.reset_rules
    rule = proc {true}
    c = Class.new(ServerSide::Controller.mount(&rule))
    r = ServerSide::Router.rules.first
    r.first.should_be rule
  end
end

class ServerSide::Controller
  attr_accessor :request, :path, :parameters, :rendered
end

class ServerSide::HTTP::Request
  attr_accessor :path, :parameters
end

require 'metaid'

class DummyController < ServerSide::Controller
  attr_reader :response_called
  
  def response
    @response_called = true
  end
  
  def render_default
    @rendered = :default
  end
end

context "ServerSide::Controller new instance" do
  specify "should set @request, @path, and @parameters instance variables" do
    req = ServerSide::HTTP::Request.new(StringIO.new)
    req.path = '/aa/bb/cc'
    req.parameters = {:q => 'node_state', :f => 'xml'}
    c = ServerSide::Controller.new(req)
    c.request.should_be req
    c.path.should_be req.path
    c.parameters.should_be req.parameters
  end
  
  specify "should invoke the response method" do
    req = ServerSide::HTTP::Request.new(StringIO.new)
    c = DummyController.new(req)
    c.response_called.should_be true
  end
  
  specify "should invoke render_default unless @rendered" do
    req = ServerSide::HTTP::Request.new(StringIO.new)
    c = DummyController.new(req)
    c.rendered.should_be :default
    
    c_class = Class.new(DummyController) do
      define_method(:response) {@rendered = true}
    end
    c = c_class.new(req)
    c.rendered.should_be true
  end
end

context "ServerSide::Controller.render_default" do
  specify "should render a default 200 response" do
    req = ServerSide::HTTP::Request.new(StringIO.new)
    c = ServerSide::Controller.new(req)
    req.socket.rewind
    resp = req.socket.read
    resp.should_match /HTTP\/1\.1\s200/
  end
end

context "ServerSide::Controller.render" do
  specify "should render a 200 response with body and content type arguments" do
    req = ServerSide::HTTP::Request.new(StringIO.new)
    c = ServerSide::Controller.new(req)
    c.render('hello world', 'text/plain')
    req.socket.rewind
    resp = req.socket.read
    resp.should_match /Content-Type:\stext\/plain\r\n/
  end
  
  specify "should set @rendered to true" do
    req = ServerSide::HTTP::Request.new(StringIO.new)
    c = ServerSide::Controller.new(req)
    c.render('hello world', 'text/plain')
    c.rendered.should == true
  end
end


