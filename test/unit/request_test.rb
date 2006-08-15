require File.dirname(__FILE__) + '/../test_helper'

class RequestTest < Test::Unit::TestCase
  class DummyRequest < ServerSide::Request::Base
    attr_reader :count
    attr_reader :conn
    
    def process
      @count ||= 0
      @count += 1
    end
  end

  def test_new
    d = DummyRequest.new('hello')
    assert_equal 'hello', d.conn
    assert_equal 1, d.count
  end
end
