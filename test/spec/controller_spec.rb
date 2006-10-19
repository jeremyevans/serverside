require File.join(File.dirname(__FILE__), '../../lib/serverside')
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
    r = ServerSide::Router.rules.first
    r.first.should_equal rule
    r.last.should_be_a_kind_of Proc
    c.module_eval do
      define_method(:initialize) {|req| $req = req}
    end
    res = r.last.call
    res.should_be_a_kind_of c
    
    r = ServerSide::Router.new(StringIO.new)
    r.path = '/test'
    r.respond
    $req.should_be_a_kind_of ServerSide::Router
  end

  specify "should accept either an argument or block as the rule" do
    ServerSide::Router.reset_rules
    rule = {:path => '/test'}
    c = ServerSide::Controller.mount(rule)
    r = ServerSide::Router.rules.first
    r.first.should_be rule

    ServerSide::Router.reset_rules
    rule = proc {true}
    c = ServerSide::Controller.mount(&rule)
    r = ServerSide::Router.rules.first
    r.first.should_be rule
  end
end
