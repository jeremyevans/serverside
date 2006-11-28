require 'socket'

module ServerSide
  module HTTP
    # The ServerSide HTTP server is designed to be fast and simple. It is also
    # designed to support both HTTP 1.1 persistent connections, and HTTP streaming
    # for applications which use Comet techniques.
    class Server
      attr_reader :listener

      # Creates a new server by opening a listening socket.
      def initialize(host, port, request_class)
        @request_class = request_class
        @listener = TCPServer.new(host, port)
      end
      
      # starts an accept loop. When a new connection is accepted, a new 
      # instance of the supplied connection class is instantiated and passed 
      # the connection for processing.
      def start
        while true
          Connection.new(@listener.accept, @request_class)
        end
      end
    end
  end
end
