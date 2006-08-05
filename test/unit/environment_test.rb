require File.dirname(__FILE__) + '/../test_helper'

class EnvironmentTest < Test::Unit::TestCase
  def test_app_root
    assert_equal true, Object.const_defined?(:APP_ROOT)
    root_path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
    assert_equal root_path, APP_ROOT 
  end
  
  def test_environment
    assert_equal 'test', ENV['ENVIRONMENT']
    assert_equal :test, ENVIRONMENT
  end
end
