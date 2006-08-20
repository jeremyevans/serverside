require File.dirname(__FILE__) + '/../test_helper'
require 'stringio'
require 'fileutils'

class ConnectionTest < Test::Unit::TestCase
  class Dummy < ServerSide::Connection::Static
    def self.static_files
      @@static_files
    end
    
    def self.mime_types
      @@mime_types
    end
    
    attr_accessor :conn, :path, :headers
    
    def initialize
      @headers = {}
    end
  end
  
  def test_cache
    assert_kind_of Hash, Dummy.static_files
    Dummy.static_files.clear
    c = Dummy.new
    c.conn = StringIO.new
    assert_nil Dummy.static_files[__FILE__]
    c.serve_file(__FILE__)
    cache = Dummy.static_files[__FILE__]
    assert_not_nil cache
    stat = File.stat(__FILE__)
    etag = (ServerSide::StaticFiles::Const::ETagFormat % 
      [stat.mtime.to_i, stat.size, stat.ino])
    assert_equal etag, cache[0]
    assert_equal IO.read(__FILE__), cache[1]
  end
  
  def test_mime_types
    assert_kind_of Hash, Dummy.mime_types
    assert_equal 'text/plain', Dummy.mime_types['.rb']
    assert_equal 'text/plain', Dummy.mime_types['.invalid']
    assert_equal 'text/html', Dummy.mime_types['.html']
    assert_equal 'text/css', Dummy.mime_types['.css']
    assert_equal 'text/javascript', Dummy.mime_types['.js']
    assert_equal 'image/gif', Dummy.mime_types['.gif']
    assert_equal 'image/jpeg', Dummy.mime_types['.jpg']
    assert_equal 'image/jpeg', Dummy.mime_types['.jpeg']
    assert_equal 'image/png', Dummy.mime_types['.png']
  end
  
  def test_serve_file_normal
    c = Dummy.new
    c.conn = StringIO.new
    c.serve_file(__FILE__)
    c.conn.rewind
    resp = c.conn.read
    
    assert_equal '200', /HTTP\/1.1\s(.*)\r\n/.match(resp)[1]
    fc = IO.read(__FILE__)
    stat = File.stat(__FILE__)
    etag = (ServerSide::StaticFiles::Const::ETagFormat % 
      [stat.mtime.to_i, stat.size, stat.ino])
    assert_equal etag, /ETag:\s(.*)\r\n/.match(resp)[1]
    assert_equal ServerSide::StaticFiles::Const::MaxAge,
      /Cache-Control:\s(.*)\r\n/.match(resp)[1]
    assert_equal stat.size.to_s,
      /Content-Length:\s(.*)\r\n/.match(resp)[1]
  end
  
  def test_serve_file_etags
    c = Dummy.new
    c.conn = StringIO.new
    Dummy.static_files.clear
    c.serve_file(__FILE__)
    c.conn.rewind
    resp = c.conn.read
    
    # normal response
    assert_equal '200', /HTTP\/1.1\s(.*)\r\n/.match(resp)[1]
    fc = IO.read(__FILE__)
    stat = File.stat(__FILE__)
    etag = (ServerSide::StaticFiles::Const::ETagFormat % 
      [stat.mtime.to_i, stat.size, stat.ino])
    assert_equal etag, /ETag:\s(.*)\r\n/.match(resp)[1]
    assert_equal ServerSide::StaticFiles::Const::MaxAge,
      /Cache-Control:\s(.*)\r\n/.match(resp)[1]
    assert_equal stat.size.to_s,
      /Content-Length:\s(.*)\r\n/.match(resp)[1]
      
    c.conn = StringIO.new
    c.headers[ServerSide::StaticFiles::Const::IfNoneMatch] = etag
    c.serve_file(__FILE__)
    c.conn.rewind
    resp = c.conn.read
    
    # not modified response
    assert_equal '304 Not Modified', /HTTP\/1.1\s(.*)\r\n/.match(resp)[1]
    fc = IO.read(__FILE__)
    stat = File.stat(__FILE__)
    etag = (ServerSide::StaticFiles::Const::ETagFormat % 
      [stat.mtime.to_i, stat.size, stat.ino])
    assert_equal etag, /ETag:\s(.*)\r\n/.match(resp)[1]
    assert_equal ServerSide::StaticFiles::Const::MaxAge,
      /Cache-Control:\s(.*)\r\n/.match(resp)[1]
    assert_equal '0', /Content-Length:\s(.*)\r\n/.match(resp)[1]
    
    FileUtils.touch(__FILE__)
    c.conn = StringIO.new
    c.headers[ServerSide::StaticFiles::Const::IfNoneMatch] = etag
    c.serve_file(__FILE__)
    c.conn.rewind
    resp = c.conn.read
    
    # modified response
    assert_equal '200', /HTTP\/1.1\s(.*)\r\n/.match(resp)[1]
    fc = IO.read(__FILE__)
    stat = File.stat(__FILE__)
    etag = (ServerSide::StaticFiles::Const::ETagFormat % 
      [stat.mtime.to_i, stat.size, stat.ino])
    assert_equal etag, /ETag:\s(.*)\r\n/.match(resp)[1]
    assert_equal ServerSide::StaticFiles::Const::MaxAge,
      /Cache-Control:\s(.*)\r\n/.match(resp)[1]
    assert_equal stat.size.to_s,
      /Content-Length:\s(.*)\r\n/.match(resp)[1]
  end
  
  def test_serve_dir
    dir = File.dirname(__FILE__)
  
    c = Dummy.new
    c.conn = StringIO.new
    Dummy.static_files.clear
    c.path = dir
    c.serve_dir(dir)
    c.conn.rewind
    resp = c.conn.read
    
    Dir.entries(dir).each do |fn|
      next if fn == '.'
      assert_not_nil resp =~ /<a href="#{dir/fn}">(#{fn})<\/a>/
    end
  end
end