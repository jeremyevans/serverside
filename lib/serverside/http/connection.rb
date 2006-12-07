require File.join(File.dirname(__FILE__), 'static')

module ServerSide
  module HTTP
    # The Connection class represents HTTP connections. Each connection
    # instance creates a separate thread for execution and processes
    # incoming requests in a loop until the connection is closed by
    # either server or client, thus implementing HTTP 1.1 persistent
    # connections.
    class Connection
      # Initializes the request instance. A new thread is created for
      # processing requests.
      def initialize(socket, request_class)
        @socket, @request_class = socket, request_class
        @thread = Thread.new {process}
      end
      
      # Processes incoming requests by parsing them and then responding. If
      # any error occurs, or the connection is not persistent, the connection 
      # is closed.
      def process
        while true
          # the process function is expected to return true or a non-nil value
          # if the connection is to persist.
          break unless @request_class.new(@socket).process
        end
      rescue => e
        # We don't care. Just close the connection.
      ensure
        @socket.close
      end
    end
  end
end