module ServerSide
  module Request
    module Const
      LineBreak = "\r\n".freeze
      RequestRegexp = /([A-Za-z]+)\s(\/.*)\sHTTP\/(.+)\r/.freeze
      HeaderRegexp = /([^:]+):\s?(.*)\r\n/.freeze
      ContentLength = 'Content-Length'.freeze
      Version_1_1 = '1.1'.freeze
      Connection = 'Connection'.freeze
      Close = 'close'.freeze
      QueryRegexp = /([^\?]+)(\?(.*))?/.freeze
      Ampersand = '&'.freeze
      ParameterRegexp = /(.+)=(.*)/.freeze
      EqualSign = '='.freeze
    end

    class Base
      def initialize(conn)
        @conn = conn
        @thread = Thread.new {process}
        @thread[:time] = Time.now
      end
      
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
        @method, @query, @version = $1.downcase.to_sym, $2, $3
        @query =~ Const::QueryRegexp
        @path = $1
        @parameters = $3 ? parse_parameters($3) : {}
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
    
    end
  end
end
