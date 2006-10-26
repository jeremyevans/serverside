require 'rubygems'
require 'metaid'
require File.join(File.dirname(__FILE__), 'connection')

module ServerSide
  module Application
    @@config = nil
  
    def self.config=(c)
      @@config = c
    end
  
    def self.daemonize(config, cmd)
      config = @@config.merge(config) if @@config
      daemon_class = Class.new(Daemon::Cluster) do
        meta_def(:pid_fn) {Daemon::WorkingDirectory/'serverside.pid'}
        meta_def(:server_loop) do |port|
          ServerSide::HTTP::Server.new(
            config[:host], port, ServerSide::Router).start
        end
        meta_def(:ports) {config[:ports]}
      end
      Daemon.control(daemon_class, cmd)
    end
  end
end
