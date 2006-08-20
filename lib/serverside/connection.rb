module ServerSide
  module Connection
    # A bunch of frozen constants to make the parsing of requests and rendering
    # of responses faster than otherwise.
    module Const
      LineBreak = "\r\n".freeze
      # Here's a nice one - parses the first line of a request.
      RequestRegexp = /([A-Za-z0-9]+)\s(\/[^\/\?]*(\/[^\/\?]+)*)\/?(\?(.*))?\sHTTP\/(.+)\r/.freeze
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
      Header = "%s: %s\r\n".freeze
      Empty = ''.freeze
      Slash = '/'.freeze
    end

    # This is the base request class. When a new request is created, it starts
    # a thread in which it is parsed and processed.
    class Base
      # Initializes the request instance. A new thread is created for
      # processing requests.
      def initialize(conn)
        @conn = conn
        @thread = Thread.new {process}
        @thread[:time] = Time.now
      end
      
      # Processes 
      def process
        while true
          break unless parse_request
          respond
          break unless @persistent
        end
      rescue => e
      ensure
        @conn.close
      end
    
      def parse_request
        return nil unless @conn.gets =~ Const::RequestRegexp
        @method, @path, @query, @version = $1.downcase.to_sym, $2, $5, $6
        @parameters = @query ? parse_parameters(@query) : {}
        @headers = {}
        while (line = @conn.gets)
          break if line.nil? || (line == Const::LineBreak)
          if line =~ Const::HeaderRegexp
            @headers[$1] = $2
          end
        end
        @persistent = (@version == Const::Version_1_1) && 
          (@headers[Const::Connection] != Const::Close)
        @headers
      end
      
      def parse_parameters(query)
        query.split(Const::Ampersand).inject({}) do |m, i|
          if i =~ Const::ParameterRegexp
            m[$1.to_sym] = $2.uri_unescape
          end
          m
        end
      end
    
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
      
      def stream(body)
        (@conn << body if body) rescue (@persistent = false)
      end
    end
  end
end
