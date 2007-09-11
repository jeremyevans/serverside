module ServerSide::HTTP
  class Response
    include Caching
    include Static
    
    attr_accessor :status, :body, :streaming
    attr_reader :headers
    
    def initialize(opts = nil)
      @status = STATUS_OK
      @headers = []
      if opts
        opts.each do |k, v|
          case k
          when :status: @status = v
          when :body: @body = v
          when :close: @close = v
          when :request: @request = v
          when :streaming: @streaming = v
          when :static: serve_static(v)
          else add_header(k.to_header_name, v)
          end
        end
      end
      unless @body || @streaming
        @body = ''
      end
    end
    
    def persistent?
      !@close && @streaming && @body
    end
    
    # Adds a header to the response.
    def add_header(k, v)
      @headers << "#{k}: #{v}\r\n"
    end
    
    ROOT_PATH = '/'.freeze
    
    # Adds a cookie to the response headers.
    def set_cookie(name, value, opts = {})
      path = opts[:path] || ROOT_PATH
      expires = opts[:expires] || (opts[:ttl] && (Time.now + opts[:ttl])) || \
        (Time.now + 86400) # if no expiry is specified we assume one day

      v = "#{name}=#{value.to_s.uri_escape}; path=#{path}; expires=#{expires.httpdate}"
      if domain = opts[:domain]
        v << "; domain=#{domain}"
      end
      add_header(SET_COOKIE, v)
    end
    
    # Adds an expired cookie to the response headers.
    def delete_cookie(name, path = nil, domain = nil)
      set_cookie(name, nil, COOKIE_EXPIRED_TIME, path, domain)
    end

    def to_s
      if !@streaming && (content_length = @body && @body.size)
        add_header(CONTENT_LENGTH, content_length)
      end
      "HTTP/1.1 #{@status}\r\nDate: #{Time.now.httpdate}\r\n#{@headers.join}\r\n#{@body}"
    end
    
    def self.redirect(location, status = STATUS_FOUND)
      new(:status => status, :location => location)
    end
    
    def self.static(path, options = {})
      new(options.merge(:static => path))
    end
    
    def self.error(e)
      new(:status => e.http_status, :close => true,
        :body => "#{e.message}\r\n#{e.backtrace.join("\r\n")}")
    end
  end
end
