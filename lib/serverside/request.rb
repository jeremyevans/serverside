require File.join(File.dirname(__FILE__), 'static')
require 'time'

module ServerSide
  module HTTP
    # A bunch of frozen constants to make the parsing of requests and rendering
    # of responses faster than otherwise.
    module Const
      LineBreak = "\r\n".freeze
      # Here's a nice one - parses the first line of a request.
      # The expected format is as follows:
      # <method> </path>[/][?<query>] HTTP/<version>
      RequestRegexp = /([A-Za-z0-9]+)\s(\/[^\/\?]*(?:\/[^\/\?]+)*)\/?(?:\?(.*))?\sHTTP\/(.+)\r/.freeze
      # Regexp for parsing headers.
      HeaderRegexp = /([^:]+):\s?(.*)\r\n/.freeze
      ContentLength = 'Content-Length'.freeze
      Version_1_1 = '1.1'.freeze
      Connection = 'Connection'.freeze
      Close = 'close'.freeze
      Ampersand = '&'.freeze
      # Regexp for parsing URI parameters.
      ParameterRegexp = /(.+)=(.*)/.freeze
      EqualSign = '='.freeze
      StatusClose = "HTTP/1.1 %d\r\nDate: %s\r\nConnection: close\r\nContent-Type: %s\r\n%s%sContent-Length: %d\r\n\r\n".freeze
      StatusStream = "HTTP/1.1 %d\r\nDate: %s\r\nConnection: close\r\nContent-Type: %s\r\n%s%s\r\n".freeze
      StatusPersist = "HTTP/1.1 %d\r\nDate: %s\r\nContent-Type: %s\r\n%s%sContent-Length: %d\r\n\r\n".freeze
      StatusRedirect = "HTTP/1.1 %d\r\nDate: %s\r\nConnection: close\r\nLocation: %s\r\n\r\n".freeze
      Header = "%s: %s\r\n".freeze
      EmptyString = ''.freeze
      EmptyHash = {}.freeze
      Slash = '/'.freeze
      Location = 'Location'.freeze
      Cookie = 'Cookie'
      SetCookie = "Set-Cookie: %s=%s; path=/; expires=%s\r\n".freeze
      CookieSplit = /[;,] */n.freeze
      CookieRegexp = /\s*(.+)=(.*)\s*/.freeze
      CookieExpiredTime  = Time.at(0).freeze
    end

    # The HTTPRequest class encapsulates HTTP requests. The request class 
    # contains methods for parsing the request and rendering a response.
    # HTTP requests are created by the connection. Descendants of HTTPRequest
    # can be created
    # When a connection is created, it creates new requests in a loop until
    # the connection is closed.
    class Request
      include StaticFiles
      
      attr_reader :conn, :method, :path, :query, :version, :parameters,
        :headers, :persistent, :cookies, :response_cookies
      
      # Initializes the request instance. Any descendants of HTTP::Request
      # which override the initialize method must receive conn as the
      # single argument, and copy it to @conn.
      def initialize(conn)
        @conn = conn
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
        return nil unless @conn.gets =~ Const::RequestRegexp
        @method, @path, @query, @version = $1.downcase.to_sym, $2, $3, $4
        @parameters = @query ? parse_parameters(@query) : {}
        @headers = {}
        while (line = @conn.gets)
          break if line.nil? || (line == Const::LineBreak)
          if line =~ Const::HeaderRegexp
            @headers[$1.freeze] = $2.freeze
          end
        end
        @persistent = (@version == Const::Version_1_1) && 
          (@headers[Const::Connection] != Const::Close)
        @cookies = @headers[Const::Cookie] ? parse_cookies : Const::EmptyHash
        @response_cookies = nil
        
        @headers
      end
      
      # Parses query parameters by splitting the query string and unescaping
      # parameter values.
      def parse_parameters(query)
        query.split(Const::Ampersand).inject({}) do |m, i|
          if i =~ Const::ParameterRegexp
            m[$1.to_sym] = $2.uri_unescape
          end
          m
        end
      end
      
      # Parses cookie values passed in the request
      def parse_cookies
        @headers[Const::Cookie].split(Const::CookieSplit).inject({}) do |m, i|
          if i =~ Const::CookieRegexp
            m[$1.to_sym] = $2.uri_unescape
          end
          m
        end
      end
    
      # Sends an HTTP response.
      def send_response(status, content_type, body = nil, content_length = nil, 
        headers = nil)
        h = headers ? 
          headers.inject('') {|m, kv| m << (Const::Header % kv)} : ''
        
        content_length = body.length if content_length.nil? && body
        @persistent = false if content_length.nil?
        
        # Select the right format to use according to circumstances.
        @conn << ((@persistent ? Const::StatusPersist : 
          (body ? Const::StatusClose : Const::StatusStream)) % 
          [status, Time.now.httpdate, content_type, h, @response_cookies, content_length])
        @conn << body if body
      rescue
        @persistent = false
      end
      
      # Send a redirect response.
      def redirect(location, permanent = false)
        @conn << (Const::StatusRedirect % [permanent ? 301 : 302, Time.now.httpdate, location])
      rescue
      ensure
        @persistent = false
      end
      
      # Streams additional data to the client.
      def stream(body)
        (@conn << body if body) rescue (@persistent = false)
      end
      
      # Sets a cookie to be included in the response.
      def set_cookie(name, value, expires)
        @response_cookies ||= ""
        @response_cookies << (Const::SetCookie % [name, value.to_s.uri_escape, expires.rfc2822])
      end
      
      # Marks a cookie as deleted. The cookie is given an expires stamp in the past.
      def delete_cookie(name)
        set_cookie(name, nil, Const::CookieExpiredTime)
      end
    end
  end
end
