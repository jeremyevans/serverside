require 'rubygems'
require 'metaid'

module ServerSide
  module Application

    class Base
      def self.configure(options)
        @config = options
      end
      
      def self.configuration
        @config
      end
      
      def initialize(host, port)
        ServerSide::Server.new(host, port, make_request_class)
      end
      
      def make_request_class
#        Class.new(ServerSide::Connection::Base) do
#          define_method(:process, self.class.compile_routing)
#        end
      end
    end
    
    class StaticServer
      def initialize(host, port)
#        ServerSide::Server.new(host, port, ServerSide::Connection::Static)
      end
    end
  end
end
