require 'socket'

module ServerSide
  class Server
    def initialize(host, port, connection_class)
      @connection_class = connection_class
      @server = TCPServer.new(host, port)
      loop {@connection_class.new(@server.accept)}
    end
  end
end
