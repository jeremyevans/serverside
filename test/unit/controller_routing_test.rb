require File.dirname(__FILE__) + '/../test_helper'

class Controller::Router
  def self.clear_rules
    @rules = []
  end
end

class ControllerRoutingTest < Test::Unit::TestCase
  def test_add_rule
    p = Proc.new {puts "hello"}
    Controller::Router.clear_rules
    Controller::Router.add_rule({:path => '/sharon'}, p)
    assert_equal 1, Controller::Router.rules.size
    assert_equal p, Controller::Router.rules.first[1]
    assert_kind_of Proc, Controller::Router.rules.first[0]

    x = 0
    Controller::Router.add_rule(:path => '/sharon') {x += 1}
    assert_equal 2, Controller::Router.rules.size
    Controller::Router.rules.first[1].call
    assert_equal 1, x
  end
  
  def test_compile_rule
    p = Controller::Router.compile_rule(:path => '/sharon')
    assert_kind_of Proc, p
    assert_nil p.call(:path => '/maumau')
    assert_not_nil p.call(:path => '/sharon/zohar')
    
    p = Controller::Router.compile_rule(:path => /^\/static\/(.+)/)
    assert_kind_of Proc, p
    assert_nil p.call(:path => '/static')
    assert_not_nil p.call(:path => '/static/js/reality.js')
  end
  
  def test_route
    a = b = false
    
    Controller::Router.clear_rules
    Controller::Router.add_rule({:path => '/a'}, Proc.new {a = true})
    Controller::Router.add_rule(:path => '/b') {b = true}
    
    Controller::Router.route(:path => '/c/1')
    assert_equal false, a
    assert_equal false, b
    Controller::Router.route(:path => '/a/1')
    assert_equal true, a
    Controller::Router.route(:path => '/b/2')
    assert_equal true, b
  end
  
  def test_mount
    Controller::Router.clear_rules
    c = Controller.mount(:path => '/43')
    assert_kind_of Class, c
    assert_equal({:path => '/43'}, c.rule)
    assert_equal 0, Controller::Router.rules.size
    
    x = 0
    d = Class.new(c) {define_method(:process) {x += 1}}
    assert_equal 1, Controller::Router.rules.size
    Controller::Router.route(:path => '/43')
    assert_equal 1, x
  end
end