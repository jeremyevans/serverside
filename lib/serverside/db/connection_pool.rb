require 'thread'

module ServerSide
  class ConnectionPool
    attr_reader :max_size, :mutex, :conn_maker
    attr_reader :available_connections, :allocated, :created_count
  
    def initialize(max_size = 4, &block)
      @max_size = max_size
      @mutex = Mutex.new
      @conn_maker = block

      @available_connections = []
      @allocated = {}
      @created_count = 0
    end
    
    def size
      @created_count
    end
    
    def hold
      while !(conn = acquire)
        sleep 0.001
      end
      yield conn
    ensure
      release
    end
    
    def acquire
      @mutex.synchronize do
        @allocated[Thread.current] ||= available
      end
    end
    
    def available
      @available_connections.pop || make_new
    end
    
    def make_new
      if @created_count < @max_size
        @created_count += 1
        @conn_maker.call
      end
    end
    
    def release
      t = Thread.current
      @mutex.synchronize do
        @available_connections << @allocated[t]
        @allocated[t] = nil
      end
    end
  end
end
