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
        start_thread_reaper
        while true
          Connection.new(@listener.accept, @request_class)
        end
      end
      
      def reap_old_threads
        now = Time.now
        Thread.list.each do |t|
          if t[:conn_start] && (now - t[:conn_start] > 300)
            t[:connection].terminate if t[:connection]
            puts "terminated thread"
          end
        end
      end
      
      def start_thread_reaper
        Thread.new do
          while true
            sleep 60
            reap_old_threads
          end
        end
      end
    end
    
    class StaticServer < Server
      def initialize(addr, port, root_path, show_dir = true)
        request_class = Class.new(Request) do
          define_method(:respond) {serve_static(root_path/@path)}
        end
        super(addr, port, request_class)
      end
    end
  end
end

