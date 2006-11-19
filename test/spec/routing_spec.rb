require File.join(File.dirname(__FILE__), '../../lib/serverside')
require 'stringio'

class ServerSide::Router
  attr_accessor :t, :parameters, :path
  
  def self.rules
    @@rules
  end
  
  def self.reset
    @@rules = []
    @@default_route = nil
    define_method(:respond) {nil}
  end
end

R = ServerSide::Router

context "Router.routes_defined?" do
  specify "should return nil if no routes were defined" do
    R.reset
    R.routes_defined?.should_be_nil
  end
  
  specify "should return true if routes were defined" do
    R.reset
    R.route('/controller') {}
    R.routes_defined?.should_be true
  end
end

context "Router.route" do
  specify "should add the rule to @@rules" do
    l = proc {1 + 1}
    R.reset
    R.route(:path => '/t', &l)
    R.rules.size.should == 1
    R.rules[0][0].should == {:path => '/t'}
    R.rules[0][1].should == l
  end
  
  specify "should convert a string argument to a path rule" do
    R.reset
    R.route('/test') {}
    R.rules[0][0].should == {:path => '/test'}
  end
  
  specify "should convert a regexp argument to a path rule" do
    R.reset
    R.route(/abc/) {}
    R.rules[0][0].should == {:path => /abc/}
  end
  
  specify "should convert an array argument into a multiple path rule" do
    R.reset
    R.route(['/a', '/b', '/c']) {}
    R.rules[0][0].should == {:path => ['/a', '/b', '/c']}
  end
  
  specify "should store a hash argument as the rule" do
    R.reset
    R.route(:a => 'abc', :b => 'def') {}
    R.rules[0][0].should_be_a_kind_of Hash
    R.rules[0][0].size.should == 2
    R.rules[0][0][:a].should == 'abc'
    R.rules[0][0][:b].should == 'def'
  end
  
  specify "should unshift new rules into the rules array" do
    R.reset
    R.route('abc') {}
    R.route('def') {}
    R.route('ghi') {}
    R.rules.size.should == 3
    R.rules[0][0][:path].should == 'ghi'
    R.rules[1][0][:path].should == 'def'
    R.rules[2][0][:path].should == 'abc'
  end
  
  specify "should accept a proc as a rule" do
    R.reset
    l1 = proc {}
    l2 = proc {}
    R.route(l1, &l2)
    R.rules.size.should == 1
    R.rules[0][0].should_be l1
    R.rules[0][1].should_be l2
  end
end

context "Router.compile_rules" do
  specify "should compile a respond method for routing requests" do
    R.reset
    R.new(StringIO.new).respond.should_be_nil
    R.rules << [{:t => 'abc'}, proc{:abc}]
    R.rules << [{:t => 'def'}, proc{:def}]
    R.default_route {:default}
    # R.compile_rules - already called by default_route
    r = R.new(StringIO.new)
    r.t = 'abc'
    r.respond.should == :abc
    r.t = 'def'
    r.respond.should == :def
    r.t = ''
    r.respond.should == :default
  end
  
  specify "should allow handlers to give up on a request, and then pass it on." do
    R.reset
    R.default_route {:default}
    R.new(StringIO.new).respond.should == :default
    R.route('.*') {@path == '/first' ? :first : nil}
    R.route('.*') {@path == '/second' ? :second : nil}
    r = R.new(StringIO.new)
    r.path = '/second'
    r.respond.should == :second
    r.path = '/first'
    r.respond.should == :first
    r.path = '/other'
    r.respond.should == :default
  end
end

context "Router.rule_to_statement" do
  specify "should define procs as methods and construct a test expression" do
    l1 = proc {}
    l2 = proc {}
    R.rule_to_statement(l1, l2).should == "if #{l1.proc_tag} && (r = #{l2.proc_tag}); return r; end\n"
    r = R.new(StringIO.new)
    r.should_respond_to l1.proc_tag
    r.should_respond_to l2.proc_tag
  end
  
  specify "should convert hash rule with single key-value to a test expression" do
    l3 = proc {}
    s = R.rule_to_statement({:path => '/.*'}, l3)
    s =~ /^if \(@path =~ ([^\(]*)\)/
    eval("R::#{$1}").should == /\/.*/
    r = R.new(StringIO.new)
    r.should_respond_to l3.proc_tag
  end
    
  specify "should convert hash with multiple key-values to an OR test expression" do
    l4 = proc {}
    
    s = R.rule_to_statement({:path => '/controller', :host => 'static'}, l4)
    s.should_match /\(@path\s=~\s([^\)]+)\)/
    s =~ /\(@path\s=~\s([^\)]+)\)/
    eval("R::#{$1}").should == /\/controller/
    s.should_match /\(@host\s=~\s([^\)]+)\)/
    s =~ /\(@host\s=~\s([^\)]+)\)/
    eval("R::#{$1}").should == /static/ 
    r = R.new(StringIO.new)
    r.should_respond_to l4.proc_tag
  end
  
  specify "should convert hash with Array value to a test expression" do
    l5 = proc {}
    s = R.rule_to_statement({:path => ['/x', '/y']}, l5)
    s =~ /^if\s\(\(@path\s=~\s([^\)]*)\)\|\|\(@path\s=~\s([^\)]*)\)\)/
    eval("R::#{$1}").should == /\/x/
    eval("R::#{$2}").should == /\/y/
    r = R.new(StringIO.new)
    r.should_respond_to l5.proc_tag
  end
end

context "Router.condition part" do
  specify "should compile a condition expression with key and value" do
    s = R.condition_part(:path, 'abc')
    s.should_match /\(@path\s=~\s(.*)\)$/
    s =~ /\(@path\s=~\s(.*)\)$/
    eval("R::#{$1}").should == /abc/
  end
  
  specify "should parse parametrized value and compile it into a lambda" do
    s = R.condition_part(:t, ':action/:id')
    (s =~ /^\((.*)\)$/).should_not_be_nil
    tag = $1
    r = R.new(StringIO.new)
    r.should_respond_to tag
    r.parameters = {}
    r.t = 'abc'
    r.send(tag).should_be false
    r.t = 'show/16'
    r.send(tag).should_be true
    r.parameters[:action].should == 'show'
    r.parameters[:id].should == '16' 
  end
end

context "Router.define_proc" do
  specify "should convert a lambda into an instance method" do
    l1 = proc {1 + 1}
    tag = R.define_proc(&l1)
    tag.should_be_a_kind_of Symbol
    tag.should == l1.proc_tag.to_sym
    r = R.new(StringIO.new)
    r.should_respond_to(tag)
    r.send(tag).should == 2
  end
end

context "Router.cache_constant" do
  specify "should cache a value as a constant inside the Router namespace" do
    c = rand(100000)
    tag = R.cache_constant(c)
    tag.should_be_a_kind_of String
    tag.should == c.const_tag
    eval("R::#{tag}").should == c
  end
end

context "Router.default_route" do
  specify "should set the default route" do
    R.default_route {'mau m'}
    R.new(StringIO.new).default_handler.should == 'mau m'

    R.default_route {654321}
    R.new(StringIO.new).default_handler.should == 654321
  end
  
  specify "should affect the result of routes_defined?" do
    R.reset
    R.routes_defined?.should_be_nil
    R.default_route {654321}
    R.routes_defined?.should_not_be_nil
  end
end

context "Router.unhandled" do
  specify "should send a 403 response" do
    r = R.new(StringIO.new)
    r.unhandled
    r.socket.rewind
    resp = r.socket.read
    resp.should_match /HTTP\/1.1\s403(.*)\r\n/
  end
end
