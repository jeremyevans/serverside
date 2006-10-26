require 'socket'

module ServerSide
  module HTTP
    # The ServerSide HTTP server is designed to be fast and simple. It is also
    # designed to support both HTTP 1.1 persistent connections, and HTTP streaming
    # for applications which use Comet techniques.
    class Server
      # Creates a new server by opening a listening socket and starting an accept
      # loop. When a new connection is accepted, a new instance of the 
      # supplied connection class is instantiated and passed the connection for
      # processing.
      def initialize(host, port, request_class)
        @server = TCPServer.new(host, port)
        while true
          Connection.new(@server.accept, request_class)
        end
      end
    end
  end
end
