require File.join(File.dirname(__FILE__), 'caching')

module ServerSide
  # This module provides functionality for serving files and directory listings
  # over HTTP.
  module Static
    include HTTP::Caching
    
    ETAG_FORMAT = '%x:%x:%x'.inspect.freeze
    TEXT_PLAIN = 'text/plain'.freeze
    TEXT_HTML = 'text/html'.freeze
    MAX_CACHE_FILE_SIZE = 100000.freeze # 100KB for the moment
    
    DIR_LISTING_START = '<html><head><title>Directory Listing for %s</title></head><body><h2>Directory listing for %s:</h2>'.freeze
    DIR_LISTING = '<a href="%s">%s</a><br/>'.freeze
    DIR_LISTING_STOP = '</body></html>'.freeze
    FILE_NOT_FOUND = 'File not found.'.freeze
    RHTML = /\.rhtml$/.freeze
    
    @@mime_types = Hash.new {|h, k| TEXT_PLAIN}
    @@mime_types.merge!({
      '.html'.freeze => 'text/html'.freeze,
      '.css'.freeze => 'text/css'.freeze,
      '.js'.freeze => 'text/javascript'.freeze,

      '.gif'.freeze => 'image/gif'.freeze,
      '.jpg'.freeze => 'image/jpeg'.freeze,
      '.jpeg'.freeze => 'image/jpeg'.freeze,
      '.png'.freeze => 'image/png'.freeze
    })
    
    @@static_files = {}
    
    # Serves a file over HTTP. The file is cached in memory for later retrieval.
    # If the If-None-Match header is included with an ETag, it is checked
    # against the file's current ETag. If there's a match, a 304 response is
    # rendered.
    def serve_file(fn)
      stat = File.stat(fn)
      etag = (ETAG_FORMAT % [stat.mtime.to_i, stat.size, stat.ino]).freeze
      validate_cache(etag, stat.mtime) do
        if @@static_files[fn] && (@@static_files[fn][0] == etag)
          content = @@static_files[fn][1]
        else
          content = IO.read(fn).freeze
          @@static_files[fn] = [etag.freeze, content]
        end
        send_response(200, @@mime_types[File.extname(fn)], content, stat.size)
      end
    rescue => e
      puts e.message
      send_response(404, TEXT_PLAIN, 'Error reading file.')
    end
    
    # Serves a directory listing over HTTP in the form of an HTML page.
    def serve_dir(dir)
      entries = Dir.entries(dir)
      entries.reject! {|fn| fn =~ /^\./}
      entries.unshift('..') if dir != './'
      html = (DIR_LISTING_START % [@path, @path]) +
        entries.inject('') {|m, fn| m << DIR_LISTING % [@path/fn, fn]} +
        DIR_LISTING_STOP
      send_response(200, 'text/html', html)
    end
    
    def serve_template(fn, b = nil)
      if (fn =~ RHTML) || (File.file?(fn = fn + '.rhtml'))
        send_response(200, TEXT_HTML, Template.render(fn, b || binding))
      end
    end
    
    # Serves static files and directory listings.
    def serve_static(path)
      if File.file?(path)
        serve_file(path)
      elsif serve_template(path)
        return
      elsif File.directory?(path)
        if File.file?(path/'index.html')
          serve_file(path/'index.html')
        elsif File.file?(path/'index.rhtml')
          serve_template(path/'index.rhtml')
        else
          serve_dir(path)
        end
      else
        send_response(404, 'text', FILE_NOT_FOUND)
      end
    rescue => e
      send_response(500, 'text', e.message)
    end
  end
end
