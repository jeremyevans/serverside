module ServerSide
  module StaticFiles
    class Cache
      @@cache = {}
      
      def self.store(fn, etag, content)
        @@cache[fn] = [etag, content]
        content
      end

      def self.recall(fn, etag)
        r = @@cache[fn]
        r && (r[0] == etag) && r[1]
      end
    end
    
    module Const
      ETag = 'ETag'.freeze
      ETagFormat = '%x:%x:%x'.inspect.freeze
      CacheControl = 'Cache-Control'.freeze
      MaxAge = "max-age=#{86400 * 30}".freeze
      IfNoneMatch = 'If-None-Match'.freeze
      NotModifiedClose = "HTTP/1.1 304 Not Modified\r\nConnection: close\r\nContent-Length: 0\r\nETag: %s\r\nCache-Control: #{MaxAge}\r\n\r\n".freeze
      NotModifiedPersist = "HTTP/1.1 304 Not Modified\r\nContent-Length: 0\r\nETag: %s\r\nCache-Control: #{MaxAge}\r\n\r\n".freeze
      TextPlain = 'text/plain'.freeze
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
  end
  
  module Connection
    module Const
      WD = '.'.freeze
      FileNotFound = "Couldn't open file %s.".freeze
    end
    
    class Static < Base
      include StaticFiles
      
      def respond
        fn = './%s' % @path
        if File.file?(fn)
          serve_file(fn)
        else
          send_response(404, 'text', Const::FileNotFound % @path)
        end
      end
    end
  end
end

