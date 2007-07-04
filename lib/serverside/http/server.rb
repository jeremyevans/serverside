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
        BasicSocket.do_not_reverse_lookup = true
        
        @listener = TCPServer.new(@host, @port)
        while true
          start_connection_thread(@listener.accept) rescue nil
        end
      end
      
      def start_connection_thread(conn)
        while Thread.list.size > 100
          sleep 1
        end
        thread = Thread.new do
          begin
            while true
              Thread.current[:timeout_stamp] = Time.now + 10
              r = @request_class.new(conn)
              should_close = r.process
              ServerSide.log_request(r)
              break unless should_close
            end
          rescue => e
            ServerSide.log_error(e)
            # We don't care. Just close the connection.
          ensure
            conn.close rescue nil
          end
        end
        thread.abort_on_exception = true
        thread = nil
      rescue => e
        puts "****************"
        puts e.message
        puts e.backtrace.first
      end
      
      def self.reap_old_workers
        now = Time.now
        Thread.list.each do |t|
          stamp = t[:timeout_stamp]
          t.raise 'Timed out' if stamp && (now >= stamp)
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
