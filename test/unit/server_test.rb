require File.dirname(__FILE__) + '/../test_helper'
require 'net/http'

class ServerTest < Test::Unit::TestCase
  class DummyRequest < ServerSide::HTTP::Request
    def respond
      @socket << "HTTP/1.1 200\r\nContent-Length: 9\r\n\r\nHi there!"
    end
  end

  def test_server_creation
    t = Thread.new do
      begin
        ServerSide::HTTP::Server.new('0.0.0.0', 17543, DummyRequest).start
      rescue => e
        puts e.message
        puts e.backtrace.first
      end
    end
    sleep 0.1

    h = Net::HTTP.new('localhost', 17543)
    resp, data = h.get('/', nil)
    assert_equal 200, resp.code.to_i
    assert_equal 'Hi there!', data
    t.exit
  end
end
