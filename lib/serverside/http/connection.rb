require File.join(File.dirname(__FILE__), 'static')
require 'timeout'

module ServerSide
  module HTTP
    # The Connection class represents HTTP connections. Each connection
    # instance creates a separate thread for execution and processes
    # incoming requests in a loop until the connection is closed by
    # either server or client, thus implementing HTTP 1.1 persistent
    # connections.
    class Connection
      attr_reader :thread
    
      # Initializes the request instance. A new thread is created for
      # processing requests.
      def initialize(socket, request_class)
#        @socket, @request_class = socket, request_class
#        @thread = Thread.new {process}
#        @thread[:conn_start] = Time.now
      end
      
      def self.create(socket, request_class)
        thread = Thread.new do
          Thread.current[:conn_start] = Time.now
          begin
            while true
              break unless request_class.new(socket).process
            end
          rescue => e
            ServerSide.log_error(e)
            raise e
            # We don't care. Just close the connection.
          ensure
            socket.close rescue nil
          end
        end
      end
      
      # Processes incoming requests by parsing them and then responding. If
      # any error occurs, or the connection is not persistent, the connection 
      # is closed.
      def process
        puts "start connection #{@socket}"
        while true
          # the process function is expected to return true or a non-nil value
          # if the connection is to persist.
          break unless @request_class.new(@socket).process
        end
      rescue => e
        ServerSide.log_error(e)
        raise e
        # We don't care. Just close the connection.
      ensure
        puts "finished connection #{@socket}"
        @socket.close rescue nil
      end
    end
  end
end
