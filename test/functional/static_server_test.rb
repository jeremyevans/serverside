require File.dirname(__FILE__) + '/../test_helper'
require 'net/http'

class StaticServerTest < Test::Unit::TestCase
  
  class StaticRequest < ServerSide::HTTP::Request
    def respond
      serve_static('.'/@path)
    end
  end
  
  def test_basic
    t = Thread.new {ServerSide::HTTP::Server.new('0.0.0.0', 17654, StaticRequest)}
    sleep 0.1

    h = Net::HTTP.new('localhost', 17654)
    resp, data = h.get('/qqq.zzz', nil)
    assert_equal 404, resp.code.to_i
    assert_equal "File not found.", data
    
    h = Net::HTTP.new('localhost', 17654)
    resp, data = h.get("/#{__FILE__}", nil)
    assert_equal 200, resp.code.to_i
    assert_equal IO.read(__FILE__), data
    assert_equal 'text/plain', resp['Content-Type']
    # Net::HTTP includes this header in the request, so our server returns
    # likewise.
    assert_equal 'close', resp['Connection']
    t.exit
  end
end
