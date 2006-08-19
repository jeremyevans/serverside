require 'rubygems'
require 'metaid'
require File.join(File.dirname(__FILE__), 'connection')

module ServerSide
  module Application

    class Base < ServerSide::Connection::Base
      def self.configure(options)
        @config = options
      end
      
      def self.configuration
        @config
      end
      
      def initialize(host, port)
        ServerSide::Server.new(host, port, make_request_class)
      end
    end
    
    class Static
      def self.daemonize(config, cmd)
        daemon_class = Class.new(Daemon::Cluster) do
          meta_def(:server_loop) {|port|
            puts "Start #{port}"
            ServerSide::Server.new(config[:host], port, ServerSide::Connection::Static)
          }
          meta_def(:ports) {$cmd_config[:ports]}
        end
        
        Daemon.control(daemon_class, cmd)
      end
    end
    
    def self.daemonize
      
    end
  end
end
