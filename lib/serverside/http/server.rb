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
        @host, @port, @request_class = host, port, request_class
      end
      
      # starts an accept loop. When a new connection is accepted, a new 
      # instance of the supplied connection class is instantiated and passed 
      # the connection for processing.
      def start
        @listener = TCPServer.new(@host, @port)
        start_reaper
        while true
          start_connection_thread(@listener.accept)
        end
      end
      
      def start_connection_thread(conn)
        thread = Thread.new do
          begin
            while true
              Thread.current[:request_start] = Time.now
              break unless @request_class.new(conn).process
            end
          rescue => e
            ServerSide.log_error(e)
            raise e
            # We don't care. Just close the connection.
          ensure
            conn.close rescue nil
          end
        end
        thread[:server] = self
        thread.priority = 1000
        thread
      end
      
      def start_reaper
        reaper = Thread.new do
          while true
            sleep 10
            now = Time.now
            Thread.exclusive do
              Thread.list.each do |t|
                if t[:server].equal?(self) && (t[:request_start])
                  t.raise 'Timed out' if (now - t[:request_start]) > 300
                end
              end
            end
          end
        end
        reaper.priority = 1000
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

require 'extras/mem'
