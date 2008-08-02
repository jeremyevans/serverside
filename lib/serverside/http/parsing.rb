module ServerSide::HTTP
  module Parsing
    REQUEST_LINE_RE = /([A-Za-z0-9]+)\s(\/[^\/\?]*(?:\/[^\/\?]+)*)\/?(?:\?(.*))?\sHTTP\/(.+)/.freeze

    # Parses a request line into a method, URI, query and HTTP version parts.
    # If a query is included, it is parsed into query parameters.
    def parse_request_line(line)
      if line =~ REQUEST_LINE_RE
        @request_line = line
        @method, @path, @query, @http_version = $1.downcase.to_sym, $2.uri_unescape, $3, $4
        @params = @query ? parse_query_parameters(@query) : {}
        
        # HTTP 1.1 connections are persistent by default.
        @persistent = @http_version == VERSION_1_1
      else
        raise BadRequestError, "Invalid request format"
      end
    end

    HEADER_RE = /([^:]+):\s*(.*)/.freeze
    
    HYPHEN = '-'.freeze
    UNDERSCORE = '_'.freeze
    
    def header_to_sym(h)
      h.downcase.gsub(HYPHEN, UNDERSCORE).to_sym
    end
    
    # Parses an HTTP header.
    def parse_header(line)
      # check header count
      if (@header_count += 1) > MAX_HEADER_COUNT
        raise BadRequestError, "Too many headers"
      end
      
      if line =~ HEADER_RE
        if $1.size > MAX_HEADER_NAME_SIZE
          raise BadRequestError, "Invalid header size"
        end
        k = header_to_sym($1)
        v = $2.freeze
        case k
        when :content_length: @content_length = v.to_i
        when :connection: @persistent = v == KEEP_ALIVE
        when :cookie: parse_cookies(v)
        end
        @headers[k] = v
      else
        puts "invalid header:"
        p line
        puts "header so far:"
        p @headers
        raise BadRequestError, "Invalid header format"
      end
    end
    
    AMPERSAND = '&'.freeze
    PARAMETER_RE = /^(.{1,64})=(.{0,8192})$/.freeze

    # Parses query parameters by splitting the query string and unescaping
    # parameter values.
    def parse_query_parameters(query)
      query.split(AMPERSAND).inject({}) do |m, i|
        if i =~ PARAMETER_RE
          k = $1
          if k.size > MAX_PARAMETER_NAME_SIZE
            raise BadRequestError, "Invalid parameter size"
          end
          v = $2
          if v.size > MAX_PARAMETER_VALUE_SIZE
            raise BadRequestError, "Invalid parameter size"
          end
          m[k.to_sym] = v.uri_unescape
        else
          raise BadRequestError, "Invalid parameter format"
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
          @cookies[$1.to_sym] = $2.uri_unescape
        else
          raise BadRequestError, "Invalid cookie format"
        end
      end
    end
    
    BOUNDARY_FIX = '--'.freeze
    
    # Parses the request body.
    def parse_body(body)
      @body = body
      
      if @headers[:content_type] =~ MULTIPART_FORM_DATA_RE
        parse_multi_part(body, BOUNDARY_FIX + $1) # body.dup so we keep the original request body?
      elsif content_type == FORM_URL_ENCODED
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
              part_name = $1.to_sym
              file_name = $3
            end
          when CONTENT_TYPE:
            file_type = v
          end
        else
          raise BadRequestError, "Invalid header in part"
        end
      end
      # check if we got the content name
      unless part_name
        raise BadRequestError, "Invalid part content"
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
  end
end