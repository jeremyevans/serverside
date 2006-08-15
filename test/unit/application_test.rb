require File.dirname(__FILE__) + '/../test_helper'

class ApplicationTest < Test::Unit::TestCase
  class App1 < ServerSide::Application::Base
    configure(:port => 8001)
  end

  class App2 < ServerSide::Application::Base
    configure(:port => 8002)
  end

  def test_config
    assert_equal 8001, App1.configuration[:port]
    assert_equal 8002, App2.configuration[:port]
  end
end
