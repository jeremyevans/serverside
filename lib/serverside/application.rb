require 'rubygems'
require 'metaid'

module ServerSide
  module Application
    class Base
      def self.config(options)
        @config = options
      end
      
      def initialize(host, port)
        # ServerSide::Server.new(host, port, make_request_class)
      end
      
      def make_request_class
#        Class.new(ServerSide::Application::Request) do
#          define_method(:process, self.class.compile_routing)
#        end
      end
    end
    
    class StaticServer
      def initialize(host, port)
        # ServerSide::Server.new(host, port, ServerSide::Request::Static)
      end
    end
  end
end
