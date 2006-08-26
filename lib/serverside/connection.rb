require File.join(File.dirname(__FILE__), 'static')

module ServerSide
  # The Connection module takes care of HTTP connection. While most HTTP servers
  # (at least the OO ones) will define separate classes for request and 
  # response, I chose to use the concept of a connection both for better
  # performance, and also because a single connection might handle multiple
  # requests, if using HTTP 1.1 persistent connection.
  module Connection
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
      StatusClose = "HTTP/1.1 %d\r\nConnection: close\r\nContent-Type: %s\r\n%sContent-Length: %d\r\n\r\n".freeze
      StatusStream = "HTTP/1.1 %d\r\nConnection: close\r\nContent-Type: %s\r\n%s\r\n".freeze
      StatusPersist = "HTTP/1.1 %d\r\nContent-Type: %s\r\n%sContent-Length: %d\r\n\r\n".freeze
      StatusRedirect = "HTTP/1.1 %d\r\nConnection: close\r\nLocation: %s\r\n\r\n".freeze
      Header = "%s: %s\r\n".freeze
      Empty = ''.freeze
      Slash = '/'.freeze
      Location = 'Location'
    end

    # This is the base request class. When a new request is created, it starts
    # a thread in which it is parsed and processed.
    #
    # Connection::Base is overriden by applications to create 
    # application-specific behavior.
    class Base
      include StaticFiles
      
      # Initializes the request instance. A new thread is created for
      # processing requests.
      def initialize(conn)
        @conn = conn
        @thread = Thread.new {process}
      end
      
      # Processes incoming requests by parsing them and then responding. If
      # any error occurs, or the connection is not persistent, the connection is
      # closed.
      def process
        while true
          break unless parse_request
          respond
          break unless @persistent
        end
      rescue => e
        puts '*******************'
        puts e.message
        puts e.backtrace.first
        puts '*******************'
        # We don't care. Just close the connection.
      ensure
        @conn.close
      end
    
      # Parses an HTTP request. If the request is not valid, nil is returned.
      # Otherwise, the HTTP headers are returned. Also determines whether the
      # connection is persistent (by checking the HTTP version and the 
      # 'Connection' header).
      def parse_request
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
    
      # Sends an HTTP response.
      def send_response(status, content_type, body = nil, content_length = nil, 
        headers = nil)
        h = headers ? 
          headers.inject('') {|m, kv| m << (Const::Header % kv)} : Const::Empty

        content_length = body.length if content_length.nil? && body
        @persistent = false if content_length.nil?
        
        # Select the right format to use according to circumstances.
        @conn << ((@persistent ? Const::StatusPersist : 
          (body ? Const::StatusClose : Const::StatusStream)) % 
          [status, content_type, h, content_length])
        @conn << body if body
      rescue
        @persistent = false
      end
      
      # Send a redirect response.
      def redirect(location, permanent = false)
        @conn << (Const::StatusRedirect % [permanent ? 301 : 302, location])
      rescue
      ensure
        @persistent = false
      end
      
      # Streams additional data to the client.
      def stream(body)
        (@conn << body if body) rescue (@persistent = false)
      end
    end
  end
end
