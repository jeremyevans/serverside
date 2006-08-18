require 'socket'

module ServerSide
  class Server
    def initialize(host, port, handler_class)
      @handler_class = handler_class
      @server = TCPServer.new(host, port)
      loop {@handler_class.new(@server.accept)}
    end
  end
end
