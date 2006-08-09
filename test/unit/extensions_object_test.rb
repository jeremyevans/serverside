require File.dirname(__FILE__) + '/../test_helper'

class ExtensionsObjectTest < Test::Unit::TestCase
  class A
  end
  
  class B
    frozen
  end

  def test_frozen_const
    assert_raise(NameError) {A::Frozen}
    assert_nothing_raised {B::Frozen}
  end
  
  class C
    class Const
    end
  end
  
  class D
    frozen
  end
  
  def test_const_missing
    assert_raise(NameError) {C::Frozen::AAA}
    assert_equal 'AAA', D::Frozen::AAA
    assert_equal true, D::Frozen::AAA.frozen?
  end
  
  class E
    frozen :A => '1234', :B => :test
  end
  
  def test_add_consts
    assert_equal '1234', E::Frozen::A
    assert_equal true, E::Frozen::A.frozen?
    assert_equal :test, E::Frozen::B
    assert_equal 'C', E::Frozen::C
    assert_equal true, E::Frozen::C.frozen?
  end
end
