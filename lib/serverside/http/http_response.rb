module ServerSide::HTTP
  module Response
    # Adds a header to the response.
    def add_header(k, v)
      @response_headers << "#{k}: #{v}\r\n"
    end
    
    # Sends a representation with a content type and a body.
    def send_representation(status, content_type, body)
      add_header(CONTENT_TYPE, content_type)
      send_response(status, body)
    end
    
    # Sends a file representation. If the request method is HEAD, the response
    # body is ommitted.
    def send_file(status, content_type, fn)
      add_header(CONTENT_TYPE, content_type)
      if @method == :head
        send_response(status, nil, File.size(fn))
      else
        send_response(status, IO.read(fn))
      end
    end
    
    def send_template(status, content_type, template, binding)
      body = ServerSide::Template.render(template, binding)
      send_representation(status, content_type, body)
    end
    
    # Sends an error response. The HTTP status code is derived from the error
    # class.
    def send_error_response(e)
      send_response(e.http_status, e.message)
    end
    
    # Sends an HTTP response.
    def send_response(status, body = nil, content_length = nil)
      # if the connection is to be closed, we add the Connection: close header.
      # prepare date and other headers
      add_header(DATE, Time.now.httpdate)
      if (content_length ||= body && body.size)
        add_header(CONTENT_LENGTH, content_length)
      else
        @persistent = false
      end
      unless @persistent
        @response_headers << CONNECTION_CLOSE
      end
      @response_sent = true
      send_data "HTTP/1.1 #{status}\r\n#{@response_headers.join}\r\n#{body}"
    end
    
    def redirect(location, permanent = false)
      add_header(LOCATION, location)
      send_response(permanent ? STATUS_MOVED_PERMANENTLY : STATUS_FOUND,'')
    end
    
    # Starts a stream
    def start_stream(status, content_type = nil, body = nil)
      @streaming = true
      if content_type
        add_header(CONTENT_TYPE, content_type)
      end
      send_response(status)
      if body
        send_data(body)
      end
    end
    
    def stream(body)
      send_data(body)
    end
    
    ROOT_PATH = '/'.freeze
    
    # Adds a cookie to the response headers.
    def set_cookie(name, value, expires, path = nil, domain = nil)
      path ||= ROOT_PATH
      v = "#{name}=#{value.to_s.uri_escape}; path=#{path}; expires=#{expires.rfc2822}"
      if domain
        v << "; domain=#{domain}"
      end
      add_header(SET_COOKIE, v)
    end
    
    # Adds an expired cookie to the response headers.
    def delete_cookie(name, path = nil, domain = nil)
      set_cookie(name, nil, COOKIE_EXPIRED_TIME, path, domain)
    end
  end
end
