require File.dirname(__FILE__) + '/../test_helper'
require 'stringio'

class ControllersRequestTest < Test::Unit::TestCase
  def test_initialize
    env = {
      'REQUEST_METHOD' => 'GET',
      'PATH_INFO' => '/test',
#      'HTTP_COOKIE' => 'ws=3231; sharon=zohar',
      'QUERY_STRING' => 'q=channel_events&id=3232',
      'REMOTE_ADDR' => '62.126.221.56'
    }
    r = Controller::Request.new({}, env, {})
    
    assert_equal({}, r.req)
    assert_equal env, r.env
    assert_equal :get, r.method
    assert_equal '/test', r.path
    assert_equal '62.126.221.56', r.remote_ip
#    assert_equal '3231', r.cookie_jar[:ws]
#    assert_equal 'zohar', r.cookie_jar[:sharon]
    assert_equal 'channel_events', r.params[:q]
    assert_equal '3232', r.params[:id]
    assert_equal 200, r.status
    assert_equal 'no-cache', r.headers['Cache-Control']
  end
  
  def test_brackets
    env = {
      'REQUEST_METHOD' => 'GET',
      'PATH_INFO' => '/test',
#      'HTTP_COOKIE' => 'ws=3231; sharon=zohar',
      'QUERY_STRING' => 'q=channel_events&id=3232',
      'REMOTE_ADDR' => '62.126.221.56'
    }
    r = Controller::Request.new({}, env, {})
    
    assert_equal env, r[:env]
    assert_equal :get, r[:method]
    assert_equal '/test', r[:path]
    assert_nil r[:invalid]
  end
  
  def test_parse_post_url_encoded
    params = 'q=node_state&id=23'
    req = StringIO.new(params)
  
    env = {
      'REQUEST_METHOD' => 'POST',
      'PATH_INFO' => '/test',
      'CONTENT_LENGTH' => params.size,
      'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
    }
    
    r = Controller::Request.new(req, env, {})
    
    assert_equal req, r.req
    assert_equal env, r.env
    assert_equal :post, r.method
    assert_equal 'node_state', r.params[:q]
    assert_equal '23', r.params[:id]
  end
  
  def test_parse_post_freeform
    body = "Il faut chercher l'innocence de l'esprit!"
    req = StringIO.new(body)
  
    env = {
      'REQUEST_METHOD' => 'POST',
      'PATH_INFO' => '/test',
      'CONTENT_LENGTH' => body.size
    }
    
    r = Controller::Request.new(req, env, {})
    
    assert_equal req, r.req
    assert_equal env, r.env
    assert_equal :post, r.method
    assert_equal body, r.body
  end
  
  def test_parse_post_url_encoded_body
    body = "Il faut chercher l'innocence de l'esprit!"
    params = "q=node_state&body=#{body.uri_escape}"
    req = StringIO.new(params)
  
    env = {
      'REQUEST_METHOD' => 'POST',
      'PATH_INFO' => '/test',
      'CONTENT_LENGTH' => params.size,
      'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
    }
    
    r = Controller::Request.new(req, env, {})
    
    assert_equal req, r.req
    assert_equal env, r.env
    assert_equal :post, r.method
    assert_equal 'node_state', r.params[:q]
    assert_equal body, r.params[:body]
  end
  
  def test_parse_parameters
    r = Controller::Request.new({}, {}, {})
    encoded = "hi. lots; of% smyb&ols here?"
    p = r.parse_parameters("encoded=#{encoded.uri_escape}&test=hello")
    
    assert_equal encoded, p[:encoded]
    assert_equal 'hello', p[:test]
    
    assert_equal ({}), r.parse_parameters('')
    assert_equal ({}), r.parse_parameters(nil)
  end
  
  class ResponseDummy
    attr_reader :status, :headers, :body
    
    def start(status, finalize)
      @status = status
      @headers = {}
      out = StringIO.new
      yield @headers, out
      out.rewind
      @body = out.read
    end
    
    def write(body)
      @body ||= ''
      @body += body
    end
  end
  
  def test_send_headers
    resp = ResponseDummy.new
    r = Controller::Request.new({}, {}, resp)
    assert_equal resp, r.response
    r.send_headers
    assert_equal 200, resp.status
    assert_equal 'no-cache', resp.headers['Cache-Control']
    assert_equal 1, resp.headers.size
    assert_equal 0, resp.body.length
    
    resp = ResponseDummy.new
    r = Controller::Request.new({}, {}, resp)
    nota = 'una nota sopra la semper est canendum fa'
    r.headers['Schatzie'] = 'mau'
    r.send_headers(nota)
    assert_equal 200, resp.status
    assert_equal 'no-cache', resp.headers['Cache-Control']
    assert_equal 'mau', resp.headers['Schatzie']
    assert_equal 2, resp.headers.size
    assert_equal nota, resp.body
  end
  
  def test_render
    resp = ResponseDummy.new
    r = Controller::Request.new({}, {}, resp)
    r.render('<test></test>', 'text/xml')
    assert_equal 200, resp.status
    assert_equal 'text/xml', resp.headers['Content-Type']
    assert_equal '<test></test>', resp.body

    r.render('<yes></yes>')
    assert_equal '<test></test><yes></yes>', resp.body
  end
  
  def test_stream
    resp = ResponseDummy.new
    r = Controller::Request.new({}, {}, resp)
    r.stream('<test></test>', 'text/xml')
    assert_equal 200, resp.status
    assert_equal 'text/xml', resp.headers['Content-Type']
    assert_equal '<test></test>', resp.body

    r.stream('<yes></yes>')
    assert_equal '<test></test><yes></yes>', resp.body
  end
  
  def test_redirect
    resp = ResponseDummy.new
    r = Controller::Request.new({}, {}, resp)
    r.redirect('http://reality.com')
    
    assert_equal 302, resp.status
    assert_equal 'http://reality.com', resp.headers['Location']
  end
  
  def test_cache_expiration
    r = Controller::Request.new({}, {}, {})
    
    assert_equal 'no-cache', r.headers['Cache-Control']
    assert_nil r.cache_expiration
    
    t = Time.now
    r.cache_expiration = t + 60
    
    assert_equal t + 60, r.cache_expiration
    assert_not_nil r.headers['Cache-Control'] =~ /max-age\=(.*)$/
    age = $1.to_f
    assert (age > 59) && (age <= 60)
    
    r.cache_expiration = nil
    assert_nil r.cache_expiration
    assert_equal 'no-cache', r.headers['Cache-Control']
  end
end
