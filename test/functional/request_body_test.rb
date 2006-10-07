require File.dirname(__FILE__) + '/../test_helper'
require 'net/http'

$r = nil
ServerSide::Router.route(:path => '/') {$r = self; send_response(200, 'text', 'OK')}
t = Thread.new {ServerSide::HTTP::Server.new('0.0.0.0', 17651, ServerSide::Router)}
sleep 0.1

class RequestBodyTest < Test::Unit::TestCase
  
  def test_basic
    h = Net::HTTP.new('localhost', 17651)

    resp = h.post('/try', 'q=node_state&f=xml', {'Content-Type' => 'application/x-www-form-urlencoded'})
    assert_equal 'OK', resp.body
    assert_not_nil $r
    assert_equal :post, $r.method
    assert_not_nil $r.body
    assert_equal 'q=node_state&f=xml', $r.body
    assert_equal 'application/x-www-form-urlencoded', $r.content_type
    assert_equal 18, $r.content_length
  end
  
  def text_to_multipart(key, value)
    return "Content-Disposition: form-data; name=\"#{key.uri_escape}\"\r\n\r\n#{value}\r\n"
  end

  def file_to_multipart(key, filename, mime_type, content)
    return "Content-Disposition: form-data; name=\"#{key.uri_escape}\"; filename=\"#{filename}\"\r\n" +
      "Content-Transfer-Encoding: binary\r\nContent-Type: #{mime_type}\r\n\r\n#{content}\r\n"
  end
  
  def upload_file(*fns)
    params = []
    fns.each_with_index do |fn, idx|
      params << file_to_multipart("file#{idx}", File.basename(fn), 
        "text/#{File.extname(fn).gsub('.', '')}", IO.read(fn))
    end
    
    boundary = '349832898984244898448024464570528145'
    query = 
      params.map{|p| '--' + boundary + "\r\n" + p}.join('') + "--" + boundary + "--\r\n"
    Net::HTTP.start('localhost', 17651).
      post2("/", query, "Content-type" => "multipart/form-data; boundary=" + boundary)
  end
  
  def test_upload
    upload_file(__FILE__)
    assert_equal :post, $r.method
    assert_not_nil $r.parameters[:file0]
    assert_equal "text/rb", $r.parameters[:file0][:type]
    assert_equal IO.read(__FILE__), $r.parameters[:file0][:content]
  end
  
  def test_multiple_uploads
    readme_fn = File.dirname(__FILE__) + '/../../README'
    upload_file(__FILE__, readme_fn)
    assert_equal :post, $r.method
    assert_not_nil $r.parameters[:file0]
    assert_not_nil $r.parameters[:file1]
    assert_equal "text/rb", $r.parameters[:file0][:type]
    assert_equal "text/", $r.parameters[:file1][:type]
    assert_equal IO.read(__FILE__), $r.parameters[:file0][:content]
    assert_equal IO.read(readme_fn), $r.parameters[:file1][:content]
  end
  
  def test_mixed_form_data
    params = [
      file_to_multipart("file", File.basename(__FILE__), "text/rb", IO.read(__FILE__)),
      text_to_multipart('warning','1'),
      text_to_multipart('profile','css2'),
      text_to_multipart('usermedium','all')      
    ]

    boundary = '349832898984244898448024464570528145'
    query = 
      params.map{|p| '--' + boundary + "\r\n" + p}.join('') + "--" + boundary + "--\r\n"
    Net::HTTP.start('localhost', 17651).
      post2("/", query, "Content-type" => "multipart/form-data; boundary=" + boundary)

    assert_equal :post, $r.method
    
    assert_not_nil $r.parameters[:file]
    assert_equal "text/rb", $r.parameters[:file][:type]
    assert_equal File.basename(__FILE__), $r.parameters[:file][:filename]
    assert_equal IO.read(__FILE__), $r.parameters[:file][:content]
    
    assert_equal '1', $r.parameters[:warning]
    assert_equal 'css2', $r.parameters[:profile]
    assert_equal 'all', $r.parameters[:usermedium]
  end
end

