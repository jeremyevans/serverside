require File.dirname(__FILE__) + '/../test_helper'

class ApplicationTest < Test::Unit::TestCase
  def test_application_base
    assert_kind_of Class, ServerSide::Application::Base
  end
end
