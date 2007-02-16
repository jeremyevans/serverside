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
#        if @@tcp_defer_accept_opts
#          @listener.setsockopt(*@@tcp_defer_accept_opts) rescue nil
#        end
        Server.start_thread_reaper
        while true
          start_connection(@listener.accept)
#          if @@tcp_cork_opts
#            conn.setsockopt(*@@tcp_cork_opts) rescue nil
#          end
#          Connection.new(conn, @request_class)
#          Connection.create(conn, @request_class)
          #sleep 0.0001 # to allow GC on last connection
        end
      end
      
      def start_connection(conn)
        thread = Thread.new do
          begin
            while true
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
        thread[:conn_start] = Time.now
        thread.priority = 1000
        nil
      end
      
      @@thread_reaper = nil
      
      def self.start_thread_reaper
        @@thread_reaper ||= Thread.new do
          puts 'start thread reaper'
          Thread.current.priority = 1000
          while true
            sleep 10
            now = Time.now
            Thread.exclusive do
            puts "reaping threads..."
              begin
                Thread.list.each do |t|
                  if t[:conn_start] && (now - t[:conn_start] > 300)
                    t.raise 'Timed out'
                  end
                end
              rescue => e
                puts e.message
                puts e.backtrace.join("\r\n")
              end
            puts "done reaping threads."
            end
          end
        end
      end

      # Shamelessly ripped from Mongrel
      def self.configure_socket_options
        case RUBY_PLATFORM
        when /linux/
          # 9 is currently TCP_DEFER_ACCEPT
          @@tcp_defer_accept_opts = [Socket::SOL_TCP, 9, 1]
          @@tcp_cork_opts = [Socket::SOL_TCP, 3, 1]
        when /freebsd/
          # Use the HTTP accept filter if available.
          # The struct made by pack() is defined in /usr/include/sys/socket.h 
          #as accept_filter_arg
          unless `/sbin/sysctl -nq net.inet.accf.http`.empty?
            @@tcp_defer_accept_opts = [Socket::SOL_SOCKET, 
              Socket::SO_ACCEPTFILTER, ['httpready', nil].pack('a16a240')]
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

ServerSide::HTTP::Server.configure_socket_options

require 'extras/mem'
