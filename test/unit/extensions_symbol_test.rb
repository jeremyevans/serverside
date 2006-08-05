require File.dirname(__FILE__) + '/../test_helper'

class ExtensionsSymbolTest < Test::Unit::TestCase
  class TestClass
    def test
      'hello'
    end
  end
  
  def test_to_proc
    p = :test.to_proc
    assert_kind_of Proc, p
    assert_equal 'hello', p.call(TestClass.new)
    
    assert_raise(NoMethodError) {:invalid_method.to_proc.call(TestClass.new)}
    
    assert_equal ['1', '2', '3'], [1, 2, 3].map(&:to_s)
  end
  
  def test_slash
    assert_equal 'sharon/test', :sharon/'test'
    assert_equal 'sharon/zohar', :sharon/:zohar
    assert_equal 'sharon/122', :sharon/122
    assert_equal '/static/boom.js', :local/'static/boom.js'
  end
end