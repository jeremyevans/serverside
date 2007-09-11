module ServerSide::HTTP
  module Static
    MIME_TYPES = {
      :html => 'text/html'.freeze,
      :css => 'text/css'.freeze,
      :js => 'text/javascript'.freeze,

      :gif => 'image/gif'.freeze,
      :jpg => 'image/jpeg'.freeze,
      :jpeg => 'image/jpeg'.freeze,
      :png => 'image/png'.freeze,
      :ico => 'image/x-icon'.freeze
    }
    MIME_TYPES.default = 'text/plain'.freeze
    
    CACHE_TTL = {}
    CACHE_TTL.default = 86400 # one day
    
    @@static_root = Dir.pwd
    
    def self.static_root
      @@static_root
    end
    
    def self.static_root=(dir)
      @@static_root = dir
    end
    
    INVALID_PATH_RE = /\.\./.freeze
    
    # Serves a static file or directory.
    def serve_static(fn)
      full_path = @@static_root/fn
      
      if fn =~ INVALID_PATH_RE
        raise BadRequestError, "Invalid path specified (#{@uri})"
      elsif !File.exists?(full_path)
        raise NotFoundError, "File not found (#{@uri})"
      end
      
      if File.directory?(full_path)
        set_directory_representation(full_path, fn)
      else
        set_file_representation(full_path, fn)
      end
    end
    
    # Sends a file representation, setting caching-related headers.
    def set_file_representation(full_path, fn)
      ext = File.extension(full_path)
      ttl = CACHE_TTL[ext]
      validate_cache :etag => File.etag(full_path), :ttl => CACHE_TTL[ext], :last_modified => File.mtime(full_path) do
        add_header(CONTENT_TYPE, MIME_TYPES[ext])
        @body = IO.read(full_path)
      end
    end
    
    DIR_TEMPLATE = '<html><head><title>Directory Listing for %s</title></head><body><h2>Directory listing for %s:</h2><ul>%s</ul></body></html>'.freeze
    DIR_LISTING = '<li><a href="%s">%s</a><br/></li>'.freeze

    # Sends a directory representation.
    def set_directory_representation(full_path, fn)
      entries = Dir.entries(full_path)
      entries.reject! {|f| f =~ /^\./}
      entries.unshift('..') if fn != '/'
      
      list = entries.map {|e| DIR_LISTING % [fn/e, e]}.join
      html = DIR_TEMPLATE % [fn, fn, list]
      add_header(CONTENT_TYPE, MIME_TYPES[:html])
      @body = html
    end
  end
end

class File
  # Returns an Apache-style ETag for the specified file.
  def self.etag(fn)
    stat = File.stat(fn)
    "#{stat.mtime.to_i.to_s(16)}-#{stat.size.to_s(16)}-#{stat.ino.to_s(16)}"
  end
  
  # Returns the extension for the file name as a symbol.
  def self.extension(fn)
    (ext = (fn =~ /\.([^\.\/]+)$/) && $1) ? ext.to_sym : nil
  end
end