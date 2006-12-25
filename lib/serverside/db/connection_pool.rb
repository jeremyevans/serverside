require 'thread'

module ServerSide
  class ConnectionPool
    attr_reader :max_size, :connections, :mutex, :conn_maker
  
    def initialize(max_size = 4, &block)
      @max_size = max_size
      @mutex = Mutex.new
      @connections = {}
      @conn_maker = block
    end
    
    def size
      @connections.size
    end
    
    def hold_connection
      conn = acquire_connection
      yield conn
    ensure
      release_connection(conn)
    end
    
    def acquire_connection
      thread = Thread.current
      conn = nil
      while !conn
        conn = find_available_connection(thread)
        break if conn
        sleep 0.1
      end
      conn
    end
    
    def find_available_connection(thread)
      @mutex.synchronize do
        conn = owned_connection(thread) || free_connection ||
          create_connection
        if conn
          @connections[conn] = thread
          return conn
        end
      end
    end
    
    def owned_connection(thread)
      @connections.each {|k, v| return k if v == thread}; nil
    end
    
    def free_connection
      @connections.each {|k, v| return k unless v}; nil
    end
    
    def create_connection
      return nil if @connections.size >= @max_size
      @conn_maker.call
    end
    
    def release_connection(conn)
      @mutex.synchronize {@connections[conn] = nil}
    end
  end
end
