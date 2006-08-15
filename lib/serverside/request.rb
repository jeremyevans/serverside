module ServerSide
  module Request
    class Base
      def initialize(conn)
        @conn = conn
        @thread = Thread.new {process}
        @thread[:time] = Time.now
      end
      
      def process
        while true
          break unless parse_request
          respond
          break unless @persistent
        end
      rescue => e
        puts e.message
        puts e.backtrace.first
      ensure
        @conn.close
      end
    end
  end
end
