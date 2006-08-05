require File.dirname(__FILE__) + '/../test_helper'

class ExtensionsKernelTest < Test::Unit::TestCase
  def test_periodically
    counter = 0
    periodically(0.1) {counter += 1}
    sleep 1
    assert counter >= 9
  end
end
