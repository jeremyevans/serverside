require File.dirname(__FILE__) + '/../test_helper'
require 'stringio'

class ServerSide::Connection::Router
  attr_accessor :t, :parameters
  
  def self.rules
    @@rules
  end
  
  def self.reset_rules
    @@rules = []
  end
  
  def self.reset_respond
    define_method(:respond) {nil}
  end
end

class RoutingTest < Test::Unit::TestCase
  R = ServerSide::Connection::Router
  
  def test_route
    l1 = lambda {1 + 1}
    R.reset_rules
    R.route('/controller/:action/:id', &l1)
    assert_equal 1, R.rules.length
    assert_equal({:path => '/controller/:action/:id'}, R.rules[0][0])
    assert_equal l1, R.rules[0][1]
    
    l2 = lambda {2 + 2}
    R.route(:host => '^static\..+', &l2)
    assert_equal 2, R.rules.length
    assert_equal({:host => '^static\..+'}, R.rules[0][0])
    assert_equal l2, R.rules[0][1]
    assert_equal({:path => '/controller/:action/:id'}, R.rules[1][0])
    assert_equal l1, R.rules[1][1]
    
    l3 = lambda {3 + 3}
    l4 = lambda {4 + 4}
    
    R.route(l3, &l4)
    assert_equal 3, R.rules.length
    assert_equal l3, R.rules[0][0]
    assert_equal l4, R.rules[0][1]
    assert_equal({:host => '^static\..+'}, R.rules[1][0])
    assert_equal l2, R.rules[1][1]
    assert_equal({:path => '/controller/:action/:id'}, R.rules[2][0])
    assert_equal l1, R.rules[2][1]
  end
  
  def test_compile_rules
    R.reset_rules
    R.reset_respond

    assert_equal nil, R.new(StringIO.new).respond
    R.rules << [{:t => 'abc'}, lambda{1}]
    R.rules << [{:t => 'def'}, lambda{2}]
    R.route_default {3}
    R.compile_rules
    r = R.new(StringIO.new)
    r.t = 'abc'
    assert_equal 1, r.respond
    r.t = 'def'
    assert_equal 2, r.respond
    r.t = ''
    assert_equal 3, r.respond
  end
  
  def test_rule_to_statement
    l1 = lambda {1 + 1}
    l2 = lambda {2 + 2}
    s = R.rule_to_statement(l1, l2)
    assert_equal "return #{l2.proc_tag} if #{l1.proc_tag}\n" ,s
    r = R.new(StringIO.new)
    assert_equal true, r.respond_to?(l1.proc_tag)
    assert_equal true, r.respond_to?(l2.proc_tag)
    
    l3 = lambda {3 + 3}
    s = R.rule_to_statement({:path => '/.*'}, l3)
    assert_not_nil s =~ /^return\s#{l3.proc_tag}\sif\s\(@path\s=~\s(.*)\)\n$/, s
    assert_equal /\/.*/, eval("R::#{$1}")
    assert_equal true, r.respond_to?(l3.proc_tag)
    
    l4 = lambda {4 + 4}
    s = R.rule_to_statement({:path => '/controller', :host => 'static'}, l4)
    assert_not_nil s =~ /^return\s#{l4.proc_tag}\sif\s\(@path\s=~\s(.*)\)&&\(@host\s=~\s(.*)\)\n$/, s
    assert_equal /\/controller/, eval("R::#{$1}")
    assert_equal /static/, eval("R::#{$2}")
    assert_equal true, r.respond_to?(l4.proc_tag)
    
    l5 = lambda {5 + 5}
    s = R.rule_to_statement({:path => ['/x', '/y']}, l5)
    assert_not_nil s =~ /^return\s#{l5.proc_tag}\sif\s\(\(@path\s=~\s(.*)\)\|\|\(@path\s=~\s(.*)\)\)\n$/, s
    assert_equal /\/x/, eval("R::#{$1}")
    assert_equal /\/y/, eval("R::#{$2}")
    assert_equal true, r.respond_to?(l5.proc_tag)
  end
  
  def test_condition_part
    s = R.condition_part(:t, 'abc')
    assert_not_nil s =~ /^\(@t\s=~\s(.*)\)$/
    assert_equal /abc/, eval("R::#{$1}")
    
    s = R.condition_part(:t, ':action/:id')
    assert_not_nil s =~ /^\((.*)\)$/
    tag = $1
    r = R.new(StringIO.new)
    assert_equal true, r.respond_to?(tag)
    r.parameters = {}
    r.t = 'abc'
    assert_equal false, r.send(tag)
    r.t = 'show/16'
    assert_equal true, r.send(tag)
    assert_equal 'show', r.parameters[:action]
    assert_equal '16', r.parameters[:id]
  end
  
  def test_define_proc
    l1 = lambda {1 + 1}
    tag = R.define_proc(&l1)
    assert_kind_of Symbol, tag
    assert_equal l1.proc_tag.to_sym, tag
    r = R.new(StringIO.new)
    assert 2, r.send(tag)
  end
  
  def test_cache_constant
    c = rand(100000)
    tag = R.cache_constant(c)
    assert_kind_of String, tag
    assert_equal c.const_tag, tag
    assert_equal c, eval("R::#{tag}")
  end
  
  def test_route_default
    R.route_default {'mau m'}
    assert_equal 'mau m', R.new(StringIO.new).default_handler

    R.route_default {654321}
    assert_equal 654321, R.new(StringIO.new).default_handler
  end
  
  def test_serverside_route
    R.reset_rules
    ServerSide.route(:path => 'abc') {1 + 1}
    assert_equal 1, R.rules.length
    assert_equal({:path => 'abc'}, R.rules[0][0])
    assert_equal 2, R.rules[0][1].call
  end
  
  def test_serverside_route_default
    ServerSide.route_default {1234}
    assert_equal 1234, R.new(StringIO.new).default_handler
  end
end