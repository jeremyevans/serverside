require 'socket'

module ServerSide::HTTP
  class Request
    include ServerSide::HTTP::Parsing
    
    attr_reader :request_line, :method, :path, :query, :http_version, :params
    attr_reader :content_length, :headers, :header_count, :persistent
    attr_reader :cookies, :body

    def initialize(conn)
      @conn = conn
      @headers = {}
      @header_count = 0
      @cookies = {}
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
    
    # Returns true if the request was received on port 443
    def encrypted?
      port == 443
    end
    
    HOST_PORT_RE = /^([^:]+):(.+)$/.freeze

    # Parses the Host header.
    def parse_host_header
      h = @headers[:host]
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
        @client_name = @headers[:x_forwarded_for]
        unless @client_name
          if addr = @conn.get_peername
            p, @client_name = Socket.unpack_sockaddr_in(addr)
          end
        end
      end
      @client_name
    end

    # Returns true if the accept header contains the supplied pattern.
    def accept?(re)
      re = Regexp.new(re) unless Regexp === re
      (h = @headers[:accept]) && (h =~ re) && true
    end
    
    def user_agent
      @headers[:user_agent]
    end
    
    def content_type
      if t = @headers[:content_type]
        t =~ /(.*);/ ? $1.strip : t
      end
    end
  end
end