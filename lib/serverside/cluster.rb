require File.join(File.dirname(__FILE__), 'daemon')

module Daemon
  # Implements a cluster controlling daemon. The daemon itself itself forks
  # a child process for each port.
  class Cluster < Base
    # Forks a child process with a specific port.
    def self.fork_server(port)
      fork do
        trap('TERM') {server_stop}
        server_loop(port)
      end
    end
    
    def self.server_stop
      exit
    end
    
    @@pids = []
  
    # Starts child processes.
    def self.start_servers
      ports.each {|p| @@pids << fork_server(p)}
    end
  
    # Stops child processes.
    def self.stop_servers
      @@pids.each {|pid| Process.kill('TERM', pid) rescue nil}
    end
  
    # The main daemon loop. Does nothing for now.
    def self.daemon_loop
      loop {sleep 60}
    end
    
    def self.daemon_stop
      # do nothing
    end
  
    # Starts child processes and calls the main loop.
    def self.start
      start_servers
      daemon_loop
    end
  
    # Stops child processes.
    def self.stop
      daemon_stop
      stop_servers
    end
  end
end
