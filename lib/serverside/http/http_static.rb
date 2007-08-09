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
    
    CACHE_AGES = {}
    CACHE_AGES.default = 86400 # one day
    
    INVALID_PATH_RE = /\.\./.freeze
    
    # Serves a static file or directory.
    def serve_static(fn)
      if fn =~ INVALID_PATH_RE
        raise MalformedRequestError, "Invalid path specified (#{@uri})"
      elsif !File.exists?(fn)
        raise FileNotFoundError, "File not found (#{@uri})"
      end
      
      if File.directory?(fn)
        send_directory_representation(fn)
      else
        send_file_representation(fn)
      end
    end
    
    # Sends a file representation, setting caching-related headers.
    def send_file_representation(fn)
      ext = File.extension(fn)
      expires = Time.now + CACHE_AGES[ext]
      cache :etag => File.etag(fn), :expires => expires, :last_modified => File.mtime(fn) do
        send_file(STATUS_OK, MIME_TYPES[ext], fn)
      end
    end
    
    DIR_TEMPLATE = '<html><head><title>Directory Listing for %s</title></head><body><h2>Directory listing for %s:</h2><ul>%s</ul></body></html>'.freeze
    DIR_LISTING = '<li><a href="%s">%s</a><br/></li>'.freeze

    # Sends a directory representation.
    def send_directory_representation(dir)
      entries = Dir.entries(dir)
      entries.reject! {|fn| fn =~ /^\./}
      entries.unshift('..') if dir != './'
      
      list = entries.map {|e| DIR_LISTING % [@uri/e, e]}.join
      html = DIR_TEMPLATE % [dir, dir, list]
      send_representation(STATUS_OK, MIME_TYPES[:html], html)
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