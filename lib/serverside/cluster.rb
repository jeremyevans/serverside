require File.join(File.dirname(__FILE__), 'daemon')

module Daemon
  # Implements a cluster controlling daemon. The daemon itself itself forks
  # a child process for each port.
  class Cluster < Base
    # Stores and recalls pids for the child processes.
    class PidFile
      FN = 'serverside_cluster.pid'
    
      # Deletes the cluster's pid file.
      def self.delete
        FileUtils.rm(FN) if File.file?(FN)
      end
    
      # Stores a pid in the cluster's pid file.
      def self.store_pid(pid)
        File.open(FN, 'a') {|f| f.puts pid}
      end
    
      # Recalls all child pids.
      def self.recall_pids
        pids = []
        File.open(FN, 'r') do |f|
          while !f.eof?
            pids << f.gets.to_i
          end
        end
        pids
      end
    end

    # Forks a child process with a specific port.
    def self.fork_server(port)
      fork do
        trap('TERM') {exit}
        server_loop(port)
      end
    end
  
    # Starts child processes.
    def self.start_servers
      PidFile.delete
      ports.each do |p|
        PidFile.store_pid(fork_server(p))
      end
    end
  
    # Stops child processes.
    def self.stop_servers
      pids = PidFile.recall_pids
      pids.each {|pid| begin; Process.kill('TERM', pid); rescue; end}
      PidFile.delete
    end
  
    # The main daemon loop. Does nothing for now.
    def self.daemon_loop
      loop {sleep 60}
    end
  
    # Starts child processes and calls the main loop.
    def self.start
      start_servers
      daemon_loop
    end
  
    # Stops child processes.
    def self.stop
      stop_servers
    end
  end
end
