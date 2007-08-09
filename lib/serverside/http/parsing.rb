module ServerSide::HTTP
  module Parsing
    REQUEST_LINE_RE = /([A-Za-z0-9]+)\s(\/[^\/\?]*(?:\/[^\/\?]+)*)\/?(?:\?(.*))?\sHTTP\/(.+)/.freeze

    # Parses a request line into a method, URI, query and HTTP version parts.
    # If a query is included, it is parsed into query parameters.
    def parse_request_line(line)
      if line =~ REQUEST_LINE_RE
        @request_line = line
        @method, @uri, @query, @http_version = $1.downcase.to_sym, $2, $3, $4
        @params = @query ? parse_query_parameters(@query) : {}
      else
        raise MalformedRequestError, "Invalid request format"
      end
    end

    HEADER_RE = /([^:]+):\s*(.*)/.freeze
    
    # Parses an HTTP header.
    def parse_header(line)
      if line =~ HEADER_RE
        k = $1.freeze
        v = $2.freeze
        case k
        when CONTENT_LENGTH: @content_length = v.to_i
        when CONNECTION: @persistent = v == KEEP_ALIVE
        when COOKIE: parse_cookies(v)
        end
        @request_headers[k] = v
      else
        raise MalformedRequestError, "Invalid header format"
      end
    end
    
    AMPERSAND = '&'.freeze
    PARAMETER_RE = /^(.{1,64})=(.{0,8192})$/.freeze

    # Parses query parameters by splitting the query string and unescaping
    # parameter values.
    def parse_query_parameters(query)
      query.split(AMPERSAND).inject({}) do |m, i|
        if i =~ PARAMETER_RE
          m[$1.to_sym] = $2.uri_unescape
        else
          raise MalformedRequestError, "Invalid parameter format"
        end
        m
      end
    end
    
    COOKIE_RE = /^(.+)=(.*)$/.freeze
    SEMICOLON = ';'.freeze
    
    # Parses a cookies header.
    def parse_cookies(cookies)
      cookies.split(SEMICOLON).each do |c|
        if c.strip =~ COOKIE_RE
          @request_cookies[$1.to_sym] = $2.uri_unescape
        else
          raise MalformedRequestError, "Invalid cookie format"
        end
      end
    end
    
    BOUNDARY_FIX = '--'.freeze
    
    # Parses the request body.
    def parse_request_body(body)
      case @request_headers[CONTENT_TYPE]
      when MULTIPART_FORM_DATA_RE:
        parse_multi_part(body, BOUNDARY_FIX + $1) # body.dup so we keep the original request body?
      when FORM_URL_ENCODED:
        parse_form_url_encoded(body)
      end
    end
    
    # Parses a multipart request body.
    def parse_multi_part(body, boundary)
      while part = body.get_up_to_boundary_with_crlf(boundary)
        unless part.empty?
          parse_part(part)
        end
      end
    end
    
    # Parses a part of a multipart body.
    def parse_part(part)
      part_name = nil
      file_name = nil
      file_type = nil
      # part headers
      while (line = part.get_line)
        break if line.empty?
        if line =~ HEADER_RE
          k = $1.freeze
          v = $2.freeze
          case k
          when CONTENT_DISPOSITION:
            case v
            when DISPOSITION_FORM_DATA_RE:
              p [$1, $2, $3]
              part_name = $1.to_sym
              file_name = $3
            end
          when CONTENT_TYPE:
            file_type = v
          end
        else
          raise MalformedRequestError, "Invalid header in part"
        end
      end
      # check if we got the content name
      unless part_name
        raise MalformedRequestError, "Invalid part content"
      end
      # part body
      part_body = part.chomp! # what's left of it
      @params ||= {}
      @params[part_name] = file_name ? 
        {:file_name => file_name, :file_content => part_body, :file_type => file_type} :
        part_body
    end
    
    # Parses query parameters passed in the body (for POST requests.)
    def parse_form_url_encoded(body)
      @params ||= {}
      @params.merge!(parse_query_parameters(body))
    end
    
    # Returns the host specified in the Host header.
    def host
      parse_host_header unless @host_header_parsed
      @host
    end
    
    # Returns the port number if specified in the Host header.
    def port
      parse_host_header unless @host_header_parsed
      @port
    end
    
    HOST_PORT_RE = /^([^:]+):(.+)$/.freeze

    # Parses the Host header.
    def parse_host_header
      h = @request_headers[HOST]
      if h =~ HOST_PORT_RE
        @host = $1
        @port = $2.to_i
      else
        @host = h
      end
      @host_header_parsed = true
    end
    
    # Returns the client name. The client name is either the value of the
    # X-Forwarded-For header, or the result of get_peername.
    def client_name
      unless @client_name
        @client_name = @request_headers[X_FORWARDED_FOR]
        unless @client_name
          if addr = get_peername
            p, @client_name = Socket.unpack_sockaddr_in(addr)
          end
        end
      end
      @client_name
    end
    
    # Returns the request content type.
    def content_type
      @content_type ||= @request_headers[CONTENT_TYPE]
    end
  end
end