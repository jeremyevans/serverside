require File.join(File.dirname(__FILE__), 'static')
require File.join(File.dirname(__FILE__), '../template')
require 'time'

module ServerSide
  module HTTP
    # The Request class encapsulates HTTP requests. The request class 
    # contains methods for parsing the request and rendering a response.
    # HTTP requests are created by the connection. Descendants of HTTPRequest
    # can be created
    # When a connection is created, it creates new requests in a loop until
    # the connection is closed.
    class Request
      
      LINE_BREAK = "\r\n".freeze
      # Here's a nice one - parses the first line of a request.
      # The expected format is as follows:
      # <method> </path>[/][?<query>] HTTP/<version>
      REQUEST_REGEXP = /([A-Za-z0-9]+)\s(\/[^\/\?]*(?:\/[^\/\?]+)*)\/?(?:\?(.*))?\sHTTP\/(.+)\r/.freeze
      # Regexp for parsing headers.
      HEADER_REGEXP = /([^:]+):\s?(.*)\r\n/.freeze
      CONTENT_LENGTH = 'Content-Length'.freeze
      VERSION_1_1 = '1.1'.freeze
      CONNECTION = 'Connection'.freeze
      CLOSE = 'close'.freeze
      AMPERSAND = '&'.freeze
      # Regexp for parsing URI parameters.
      PARAMETER_REGEXP = /(.+)=(.*)/.freeze
      EQUAL_SIGN = '='.freeze
      STATUS_CLOSE = "HTTP/1.1 %d\r\nDate: %s\r\nConnection: close\r\nContent-Type: %s\r\n%s%sContent-Length: %d\r\n\r\n".freeze
      STATUS_STREAM = "HTTP/1.1 %d\r\nDate: %s\r\nConnection: close\r\nContent-Type: %s\r\n%s%s\r\n".freeze
      STATUS_PERSIST = "HTTP/1.1 %d\r\nDate: %s\r\nContent-Type: %s\r\n%s%sContent-Length: %d\r\n\r\n".freeze
      STATUS_REDIRECT = "HTTP/1.1 %d\r\nDate: %s\r\nConnection: close\r\nLocation: %s\r\n\r\n".freeze
      HEADER = "%s: %s\r\n".freeze
      EMPTY_STRING = ''.freeze
      EMPTY_HASH = {}.freeze
      SLASH = '/'.freeze
      LOCATION = 'Location'.freeze
      COOKIE = 'Cookie'
      SET_COOKIE = "Set-Cookie: %s=%s; path=/; expires=%s\r\n".freeze
      COOKIE_SPLIT = /[;,] */n.freeze
      COOKIE_REGEXP = /\s*(.+)=(.*)\s*/.freeze
      COOKIE_EXPIRED_TIME  = Time.at(0).freeze
      CONTENT_TYPE = "Content-Type".freeze
      CONTENT_TYPE_URL_ENCODED = 'application/x-www-form-urlencoded'.freeze
      
      include Static
      
      attr_reader :socket, :method, :path, :query, :version, :parameters,
        :headers, :persistent, :cookies, :response_cookies, :body,
        :content_length, :content_type, :response_headers
      
      # Initializes the request instance. Any descendants of HTTP::Request
      # which override the initialize method must receive socket as the
      # single argument, and copy it to @socket.
      def initialize(socket)
        @socket = socket
        @response_headers = {}
      end

      # Processes the request by parsing it and then responding.      
      def process
        parse && ((respond || true) && @persistent)
      end
      
      # Parses an HTTP request. If the request is not valid, nil is returned.
      # Otherwise, the HTTP headers are returned. Also determines whether the
      # connection is persistent (by checking the HTTP version and the 
      # 'Connection' header).
      def parse
        return nil unless @socket.gets =~ REQUEST_REGEXP
        @method, @path, @query, @version = $1.downcase.to_sym, $2, $3, $4
        @parameters = @query ? parse_parameters(@query) : {}
        @headers = {}
        while (line = @socket.gets)
          break if line.nil? || (line == LINE_BREAK)
          if line =~ HEADER_REGEXP
            @headers[$1.freeze] = $2.freeze
          end
        end
        @persistent = (@version == VERSION_1_1) && 
          (@headers[CONNECTION] != CLOSE)
        @cookies = @headers[COOKIE] ? parse_cookies : EMPTY_HASH
        @response_cookies = nil
        
        if @content_length = @headers[CONTENT_LENGTH].to_i
          @content_type = @headers[CONTENT_TYPE] || CONTENT_TYPE_URL_ENCODED
          @body = @socket.read(@content_length) rescue nil
          parse_body
        end
        
        p self
        
        @headers
      end
      
      # Parses query parameters by splitting the query string and unescaping
      # parameter values.
      def parse_parameters(query)
        query.split(AMPERSAND).inject({}) do |m, i|
          if i =~ PARAMETER_REGEXP
            m[$1.to_sym] = $2.uri_unescape
          end
          m
        end
      end
      
      # Parses cookie values passed in the request
      def parse_cookies
        @headers[COOKIE].split(COOKIE_SPLIT).inject({}) do |m, i|
          if i =~ COOKIE_REGEXP
            m[$1.to_sym] = $2.uri_unescape
          end
          m
        end
      end
      
      MULTIPART_REGEXP = /multipart\/form-data.*boundary=\"?([^\";,]+)/n.freeze
      CONTENT_DISPOSITION_REGEXP = /^Content-Disposition: form-data;([^\r]*)/m.freeze
      FIELD_ATTRIBUTE_REGEXP = /\s*(\w+)=\"([^\"]*)/.freeze
      CONTENT_TYPE_REGEXP = /^Content-Type: ([^\r]*)/m.freeze

      # parses the body, either by using
      def parse_body
        if @content_type == CONTENT_TYPE_URL_ENCODED
          @parameters.merge! parse_parameters(@body)
        elsif @content_type =~ MULTIPART_REGEXP
          boundary = "--#$1"
          r = /(?:\r?\n|\A)#{Regexp::quote("--#$1")}(?:--)?\r\n/m
          @body.split(r).each do |pt|
            headers, payload = pt.split("\r\n\r\n", 2)
            atts = {}
            if headers =~ CONTENT_DISPOSITION_REGEXP
              $1.split(';').map do |part|
                if part =~ FIELD_ATTRIBUTE_REGEXP
                  atts[$1.to_sym] = $2
                end
              end
            end
            if headers =~ CONTENT_TYPE_REGEXP
              atts[:type] = $1
            end
            if name = atts[:name]
              atts[:content] = payload
              @parameters[name.to_sym] = atts[:filename] ? atts : atts[:content]
            end
          end
        end
      end
    
      # Sends an HTTP response.
      def send_response(status, content_type, body = nil, content_length = nil, 
        headers = nil)
        @response_headers.merge!(headers) if headers
        h = @response_headers.inject('') {|m, kv| m << (HEADER % kv)}
        
        # calculate content_length if needed. if we dont have the 
        # content_length, we consider the response as a streaming response, 
        # and so the connection will not be persistent.
        content_length = body.length if content_length.nil? && body
        @persistent = false if content_length.nil?
        
        # Select the right format to use according to circumstances.
        @socket << ((@persistent ? STATUS_PERSIST : 
          (body ? STATUS_CLOSE : STATUS_STREAM)) % 
          [status, Time.now.httpdate, content_type, h, @response_cookies, 
            content_length])
        @socket << body if body
      rescue => e
        @persistent = false
        raise e
      end
      
      CONTENT_DISPOSITION = 'Content-Disposition'.freeze
      CONTENT_DESCRIPTION = 'Content-Description'.freeze

      def send_file(content, content_type, disposition = :inline, 
        filename = nil, description = nil)
        disposition = filename ?
          "#{disposition}; filename=#{filename}" : disposition
        @response_headers[CONTENT_DISPOSITION] = disposition
        @response_headers[CONTENT_DESCRIPTION] = description if description
        send_response(200, content_type, content)
      end
      
      def render_template(content_type, name, binding)
        send_response(200, content_type, Template.render(name, binding))
      end
      
      # Send a redirect response.
      def redirect(location, permanent = false)
        @socket << (STATUS_REDIRECT % 
          [permanent ? 301 : 302, Time.now.httpdate, location])
      ensure
        @persistent = false
      end
      
      # Streams additional data to the client.
      def stream(body)
        (@socket << body if body) rescue (@persistent = false)
      end
      
      # Sets a cookie to be included in the response.
      def set_cookie(name, value, expires)
        @response_cookies ||= ""
        @response_cookies <<
          (SET_COOKIE % [name, value.to_s.uri_escape, expires.rfc2822])
      end
      
      # Marks a cookie as deleted. The cookie is given an expires stamp in 
      # the past.
      def delete_cookie(name)
        set_cookie(name, nil, COOKIE_EXPIRED_TIME)
      end
    end
  end
end
