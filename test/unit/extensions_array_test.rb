require File.dirname(__FILE__) + '/../test_helper'

class ExtensionsArrayTest < Test::Unit::TestCase
  def test_map
    assert_equal ['1', '2', '3'], [1, 2, 3].map {|i| i.to_s}
    assert_equal [4, 5, 6], [1, 2, 3].map {|i| i + 3}
    assert_equal ['1', '2', '3'], [1, 2, 3].map(&Proc.new {|i| i.to_s})
    
    assert_equal ['1', '2', '3'], [1, 2, 3].map(:to_s)
    assert_equal [4, 5, 6], [1, 2, 3].map(:"+", 3)
  end
  
  def test_pluck_first(&block)
    a = []
    assert_nil a.pluck_first {|i| i > 10}
    
    a = [1, 3, 6]
    assert_nil a.pluck_first {|i| i > 10}
    
    a = [7, 10, 12, 76]
    assert_equal 12, a.pluck_first {|i| i > 10 && i}
  end
end
