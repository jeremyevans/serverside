require File.join(File.dirname(__FILE__), '../../lib/serverside')
require 'stringio'
require 'fileutils'

class Dummy < ServerSide::HTTP::Request
  def self.static_files
    @@static_files
  end
  
  def self.mime_types
    @@mime_types
  end
  
  attr_accessor :path, :socket, :headers
  
  def initialize
    super(nil)
    @headers = {}
  end
end

include ServerSide

context "Static.static_files" do
  specify "Should cache served files, along with their etag" do
    Dummy.static_files.should_be_a_kind_of Hash
    Dummy.static_files.clear
    c = Dummy.new
    c.socket = StringIO.new
    Dummy.static_files[__FILE__].should_be_nil
    c.serve_file(__FILE__)
    cache = Dummy.static_files[__FILE__]
    cache.should_not_be_nil
    stat = File.stat(__FILE__)
    etag = (ServerSide::Static::ETAG_FORMAT % 
      [stat.mtime.to_i, stat.size, stat.ino])
    cache[0].should == etag
    cache[1].should == IO.read(__FILE__)
  end
end

context "Static.mime_types" do
  specify "should be a hash" do
    Dummy.mime_types.should_be_a_kind_of Hash
  end
  
  specify "should return text/plain as the default mime type" do
    Dummy.mime_types['.rb'].should == 'text/plain'
    Dummy.mime_types['.invalid'].should == 'text/plain'
  end
  
  specify "should return the correct mime type for common files" do
    Dummy.mime_types['.html'].should == 'text/html' 
    Dummy.mime_types['.css'].should == 'text/css' 
    Dummy.mime_types['.js'].should == 'text/javascript' 
    Dummy.mime_types['.gif'].should == 'image/gif' 
    Dummy.mime_types['.jpg'].should == 'image/jpeg' 
    Dummy.mime_types['.jpeg'].should == 'image/jpeg' 
    Dummy.mime_types['.png'].should == 'image/png'
  end
end

context "Static.serve_file" do
  specify "should render correctly with file content, etag and size" do
    c = Dummy.new
    c.socket = StringIO.new
    c.serve_file(__FILE__)
    c.socket.rewind
    resp = c.socket.read
    
    resp.should_match /HTTP\/1.1\s200(.*)\r\n/
    fc = IO.read(__FILE__)
    stat = File.stat(__FILE__)
    etag = (ServerSide::Static::ETAG_FORMAT % 
      [stat.mtime.to_i, stat.size, stat.ino])
    resp.should_match /ETag:\s"#{etag}"\r\n/
    resp.should_match /Content-Length:\s#{stat.size.to_s}\r\n/
  end
  
  specify "should send a not modified response only if a correct etag is specified in the request" do
    stat = File.stat(__FILE__)
    etag = (ServerSide::Static::ETAG_FORMAT % 
      [stat.mtime.to_i, stat.size, stat.ino])

    # normal response
    c = Dummy.new
    c.socket = StringIO.new
    Dummy.static_files.clear
    c.serve_file(__FILE__)
    c.socket.rewind
    resp = c.socket.read
    
    resp.should_match /HTTP\/1.1\s200(.*)\r\n/
    resp.should_match /ETag:\s"#{etag}"\r\n/
    resp.should_match /Content-Length:\s#{stat.size.to_s}\r\n/
      
    # normal response (invalid etag)
    c = Dummy.new
    c.socket = StringIO.new
    c.headers['If-None-Match'] = "\"xxx-yyy\""
    Dummy.static_files.clear
    c.serve_file(__FILE__)
    c.socket.rewind
    resp = c.socket.read
    
    resp.should_match /HTTP\/1.1\s200(.*)\r\n/
    resp.should_match /ETag:\s"#{etag}"\r\n/
    resp.should_match /Content-Length:\s#{stat.size.to_s}\r\n/
    
    # not modified (etag specified)
    c.socket = StringIO.new
    c.headers['If-None-Match'] = "\"#{etag}\""
    c.valid_etag?(etag).should_be true
    c.serve_file(__FILE__)
    c.socket.rewind
    resp = c.socket.read

    resp.should_match /HTTP\/1.1\s304(.*)\r\n/

    # modified response (file stamp changed)
    FileUtils.touch(__FILE__)
    c.socket = StringIO.new
    c.headers['If-None-Match'] = etag
    c.serve_file(__FILE__)
    c.socket.rewind
    resp = c.socket.read
    
    resp.should_match /HTTP\/1.1\s200(.*)\r\n/
    stat = File.stat(__FILE__)
    etag = (ServerSide::Static::ETAG_FORMAT % 
      [stat.mtime.to_i, stat.size, stat.ino])
    resp.should_match /ETag:\s"#{etag}"\r\n/
    resp.should_match /Content-Length:\s#{stat.size.to_s}\r\n/
  end

  specify "should serve a 404 response for invalid files" do
    c = Dummy.new
    c.socket = StringIO.new
    c.serve_file('invalid_file.html')
    c.socket.rewind
    resp = c.socket.read
    
    resp.should_match /HTTP\/1.1\s404(.*)\r\n/
  end
end

class IO
  def self.write(fn, content)
    File.open(fn, 'w') {|f| f << content}
  end
end

class ServerSide::Template
  def self.reset
    @@templates = {}
  end
end


context "Static.serve_template" do
  specify "should render .rhtml file as template" do
    IO.write('tmp.rhtml', '<%= @t %>')
    @t = Time.now.to_f
    c = Dummy.new
    c.socket = StringIO.new
    c.serve_template('tmp.rhtml', binding)
    c.socket.rewind
    resp = c.socket.read
    resp.should.match /\r\n\r\n#{@t}$/
    FileUtils.rm('tmp.rhtml')
  end
  
  specify "should use its own binding when none is specified" do
    Template.reset
    IO.write('tmp.rhtml', '<%= @path %>')

    c = Dummy.new
    c.socket = StringIO.new
    c.path = '/test/hey'
    c.serve_template('tmp.rhtml')
    c.socket.rewind
    resp = c.socket.read
    resp.should.match /\r\n\r\n\/test\/hey$/
    FileUtils.rm('tmp.rhtml')
  end
end

context "Static.serve_dir" do
  specify "should render a directory with all its entries" do
    dir = File.dirname(__FILE__)
  
    c = Dummy.new
    c.socket = StringIO.new
    Dummy.static_files.clear
    c.path = dir
    c.serve_dir(dir)
    c.socket.rewind
    resp = c.socket.read
    
    Dir.entries(dir).each do |fn|
      next if fn =~ /^\./
      resp.should_match /<a href="#{dir/fn}">(#{fn})<\/a>/
    end
  end
end

context "Static.serve_static" do
  specify "should serve directories" do
    dir = File.dirname(__FILE__)
  
    c = Dummy.new
    c.socket = StringIO.new
    Dummy.static_files.clear
    c.path = dir
    c.serve_static(dir)
    c.socket.rewind
    resp = c.socket.read
    
    Dir.entries(dir).each do |fn|
      next if fn =~ /^\./
      resp.should_match /<a href="#{dir/fn}">(#{fn})<\/a>/
    end
  end
  
  specify "should serve files" do
    c = Dummy.new
    c.socket = StringIO.new
    c.serve_static(__FILE__)
    c.socket.rewind
    resp = c.socket.read
    
    # normal response
    resp.should_match /HTTP\/1.1\s200(.*)\r\n/
    stat = File.stat(__FILE__)
    etag = (ServerSide::Static::ETAG_FORMAT % 
      [stat.mtime.to_i, stat.size, stat.ino])
    resp.should_match /ETag:\s"#{etag}"\r\n/
    resp.should_match /Content-Length:\s#{stat.size.to_s}\r\n/
  end
  
  specify "should serve templates" do
    Template.reset
    IO.write('tmp.rhtml', '<%= 1 + 1%>')

    c = Dummy.new
    c.socket = StringIO.new
    c.serve_static('tmp.rhtml')
    c.socket.rewind
    resp = c.socket.read
    
    resp.should_match /HTTP\/1.1\s200(.*)\r\n/
    resp.should_match /\r\n\r\n2$/
    
    FileUtils.rm('tmp.rhtml')
  end
  
  specify "should serve index.html if exists in directory path" do
    dir = File.dirname(__FILE__)/:tmp_dir
    FileUtils.mkdir(dir) rescue nil
    begin
      IO.write(dir/'index.html', '<h1>HI</h1>')
      c = Dummy.new
      c.socket = StringIO.new
      c.serve_static(dir)
      c.socket.rewind
      resp = c.socket.read
    
      resp.should_match /HTTP\/1.1\s200(.*)\r\n/
      resp.should_match /\r\n\r\n<h1>HI<\/h1>$/
      resp.should_match /Content-Type: text\/html/
    ensure
      FileUtils.rmtree(dir) rescue nil
    end
  end
  
  specify "should serve index.rhtml if exists in directory path" do
    dir = File.dirname(__FILE__)/:tmp_dir
    FileUtils.mkdir(dir) rescue puts "dir already exists"
    begin
      IO.write(dir/'index.rhtml', '<h1><%= @path %></h1>')
      c = Dummy.new
      c.socket = StringIO.new
      c.path = dir
      c.serve_static(dir)
      c.socket.rewind
      resp = c.socket.read
    
      resp.should_match /HTTP\/1.1\s200(.*)\r\n/
      resp.should_match /\r\n\r\n<h1>#{dir}<\/h1>$/
      resp.should_match /Content-Type: text\/html/
    ensure
      FileUtils.rmtree(dir) rescue nil
    end
  end
  
  specify "should serve a 404 response for invalid files" do
    c = Dummy.new
    c.socket = StringIO.new
    c.serve_static('invalid_file.html')
    c.socket.rewind
    resp = c.socket.read
    
    resp.should_match /HTTP\/1.1\s404(.*)\r\n/
  end
end
