require File.dirname(__FILE__) + '/../test_helper'
require 'net/http'

class ServerTest < Test::Unit::TestCase
  class DummyConnection
    attr_reader :conn
    @@count = 0
    def initialize(conn)
      @@count += 1
      @conn = conn
      @conn << "HTTP/1.1 200\r\nContent-Length: 9\r\n\r\nHi there!"
      @conn.close
    end
  end

  def test_server_creation
    t = Thread.new {ServerSide::Server.new('0.0.0.0', 17543, DummyConnection)}
    sleep 0.1

    h = Net::HTTP.new('localhost', 17543)
    resp, data = h.get('/', nil)
    assert_equal 200, resp.code.to_i
    assert_equal 'Hi there!', data
    t.exit
  end
end
