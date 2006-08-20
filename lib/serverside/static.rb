module ServerSide
  # This module provides functionality for serving files and directory listings
  # over HTTP. It is mainly used by ServerSide::Connection::Static.
  module StaticFiles
    # Frozen constants to be used by the module.
    module Const
      ETag = 'ETag'.freeze
      ETagFormat = '%x:%x:%x'.inspect.freeze
      CacheControl = 'Cache-Control'.freeze
      MaxAge = "max-age=#{86400 * 30}".freeze
      IfNoneMatch = 'If-None-Match'.freeze
      NotModifiedClose = "HTTP/1.1 304 Not Modified\r\nConnection: close\r\nContent-Length: 0\r\nETag: %s\r\nCache-Control: #{MaxAge}\r\n\r\n".freeze
      NotModifiedPersist = "HTTP/1.1 304 Not Modified\r\nContent-Length: 0\r\nETag: %s\r\nCache-Control: #{MaxAge}\r\n\r\n".freeze
      TextPlain = 'text/plain'.freeze
      MaxCacheFileSize = 100000.freeze # 100KB for the moment
      
      DirListingStart = '<html><head><title>Directory Listing for %s</title></head><body><h2>Directory listing for %s:</h2>'.freeze
      DirListing = '<a href="%s">%s</a><br/>'.freeze
      DirListingStop = '</body></html>'.freeze
    end
    
    @@mime_types = Hash.new {|h, k| ServerSide::StaticFiles::Const::TextPlain}
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
      etag = (Const::ETagFormat % [stat.mtime.to_i, stat.size, stat.ino]).freeze
      unless etag == @headers[Const::IfNoneMatch]
        if @@static_files[fn] && (@@static_files[fn][0] == etag)
          content = @@static_files[fn][1]
        else
          content = IO.read(fn).freeze
          @@static_files[fn] = [etag.freeze, content]
        end
        
        send_response(200, @@mime_types[File.extname(fn)], content, stat.size, 
          {Const::ETag => etag, Const::CacheControl => Const::MaxAge})
      else
        @conn << ((@persistent ? Const::NotModifiedPersist : 
          Const::NotModifiedClose) % etag)
      end
    rescue => e
      send_response(404, Const::TextPlain, 'Error reading file.')
    end
    
    # Serves a directory listing over HTTP in the form of an HTML page.
    def serve_dir(dir)
      html = (Const::DirListingStart % [@path, @path]) +
        Dir.entries(dir).inject('') {|m, fn|
          (fn == '.') ? m : m << Const::DirListing % [@path/fn, fn]
        } + Const::DirListingStop
      send_response(200, 'text/html', html)
    end
  end
  
  module Connection
    module Const
      WD = '.'.freeze
      FileNotFound = "Couldn't open file %s.".freeze
    end
    
    # A connection type for serving static files.
    class Static < Base
      include StaticFiles
      
      # Responds with a file's content or a directory listing. If the path
      # does not exist, a 404 response is rendered.
      def respond
        fn = './%s' % @path
        if File.file?(fn)
          serve_file(fn)
        elsif File.directory?(fn)
          serve_dir(fn)
        else
          send_response(404, 'text', Const::FileNotFound % @path)
        end
      end
    end
  end
end

