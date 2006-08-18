require File.dirname(__FILE__) + '/../test_helper'
require 'net/http'

class StaticServerTest < Test::Unit::TestCase
  
  class StaticConnection < ServerSide::Connection::Base
    def respond
      status = 200
      body = IO.read('.'/@path)
    rescue => e
      status = 404
      body = "Couldn't open file #{@path}."
    ensure
      send_response(status, 'text', body)
    end
  end
  
  def test_basic
    t = Thread.new {ServerSide::Server.new('0.0.0.0', 17654, StaticConnection)}
    sleep 0.1

    h = Net::HTTP.new('localhost', 17654)
    resp, data = h.get('/qqq', nil)
    assert_equal 404, resp.code.to_i
    assert_equal "Couldn't open file /qqq.", data
    
    h = Net::HTTP.new('localhost', 17654)
    resp, data = h.get("/#{__FILE__}", nil)
    assert_equal 200, resp.code.to_i
    assert_equal IO.read(__FILE__), data
    assert_equal 'text', resp['Content-Type']
    # Net::HTTP includes this header in the request, so our server returns
    # likewise.
    assert_equal 'close', resp['Connection']
    t.exit
  end
end
