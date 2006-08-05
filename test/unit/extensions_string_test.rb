require File.dirname(__FILE__) + '/../test_helper'

class ExtensionsStringTest < Test::Unit::TestCase
  def test_uri_escape
    assert_equal 'hello', 'hello'.uri_escape
    assert_equal 'hello+world', 'hello world'.uri_escape
    assert_equal 'Hello%2C+my+name+is+Inigo+Montoya%21',
      'Hello, my name is Inigo Montoya!'.uri_escape
  end
  
  def test_uri_unescape
    assert_equal 'hello', 'hello'.uri_unescape
    assert_equal 'hello world', 'hello+world'.uri_unescape
    assert_equal 'Hello, my name is Inigo Montoya!',
      'Hello%2C+my+name+is+Inigo+Montoya%21'.uri_unescape
    assert_equal '%&asdf#231&?fgs!', '%&asdf#231&?fgs!'.uri_escape.uri_unescape 
  end
  
  def test_slash
    assert_equal 'sharon/eylon', 'sharon'/'eylon'
    assert_equal 'sharon/122', 'sharon'/122
    assert_equal 'test/schmest', 'test'/:schmest
  end
end
