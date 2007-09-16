module ServerSide::HTTP
  class Response
    include Caching
    include Static
    
    attr_accessor :status, :body, :request
    attr_reader :headers, :stream_period, :stream_proc
    
    def initialize(opts = nil)
      @status = STATUS_OK
      @headers = []
      @body = ''
      if opts
        opts.each do |k, v|
          case k
          when :status: @status = v
          when :body: @body = v
          when :close: @close = v
          when :request: @request = v
          when :static: serve_static(v)
          else add_header(k, v)
          end
        end
      end
    end
    
    def disable_response
      @disable_response = true
    end
    
    def enable_response
      @disable_response = false
    end
    
    def persistent?
      !@close && !@stream_proc && @body
    end
    
    # Adds a header to the response.
    def add_header(k, v)
      k = k.to_header_name if (k.class == Symbol)
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
    def delete_cookie(name, opts = {})
      set_cookie(name, nil, opts.merge(:expires => COOKIE_EXPIRED_TIME))
    end

    EMPTY = ''.freeze
    
    def to_s
      if @disable_response
        EMPTY
      else
        if !streaming? && (content_length = @body && @body.size)
          add_header(CONTENT_LENGTH, content_length)
        end
        "HTTP/1.1 #{@status}\r\nDate: #{Time.now.httpdate}\r\n#{@headers.join}\r\n#{@body}"
      end
    end
    
    def stream(period, &block)
      @stream_period = period
      @stream_proc = block
      self
    end
    
    def streaming?
      @stream_proc
    end
    
    def self.blank
      new(:body => nil)
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
    
    def self.streaming(opts = nil, &block)
      new(opts).stream(1, &block)
    end
    
    def set_representation(body, content_type)
      @body = body
      add_header(CONTENT_TYPE, content_type)
    end
    
    def redirect(location, status = STATUS_FOUND)
      @status = status
      add_header(:location, location)
    end
    
    def content_type=(v)
      add_header(CONTENT_TYPE, v)
    end
  end
end
