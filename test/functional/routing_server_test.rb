require File.dirname(__FILE__) + '/../test_helper'
require 'net/http'

class StaticServerTest < Test::Unit::TestCase
  def test_basic
    ServerSide::route(:path => '^/static/:path') {serve_static('.'/@parameters[:path])}
    ServerSide::route(:path => '/hello$') {send_response(200, 'text', 'Hello world!')}
    ServerSide.route(:path => '/xml/:flavor/feed.xml') do
      redirect('http://feeds.feedburner.com/RobbyOnRails')
    end
    
    t = Thread.new {ServerSide::Server.new('0.0.0.0', 17654, ServerSide::Connection::Router)}
    sleep 0.1

    h = Net::HTTP.new('localhost', 17654)
    resp, data = h.get('/hello', nil)
    assert_equal 200, resp.code.to_i
    assert_equal "Hello world!", data
    
    h = Net::HTTP.new('localhost', 17654)
    resp, data = h.get('/static/qqq.zzz', nil)
    assert_equal 404, resp.code.to_i
    assert_equal "File not found.", data
    
    h = Net::HTTP.new('localhost', 17654)
    resp, data = h.get("/static/#{__FILE__}", nil)
    assert_equal 200, resp.code.to_i
    assert_equal IO.read(__FILE__), data
    assert_equal 'text/plain', resp['Content-Type']
    # Net::HTTP includes this header in the request, so our server returns
    # likewise.
    assert_equal 'close', resp['Connection']
    
    h = Net::HTTP.new('localhost', 17654)
    resp, data = h.get('/xml/rss/feed.xml', nil)
    assert_equal 302, resp.code.to_i
    assert_equal 'http://feeds.feedburner.com/RobbyOnRails', resp['Location']
    
    t.exit
  end
end
