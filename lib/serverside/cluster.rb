require File.join(File.dirname(__FILE__), 'daemon')

module Daemon
  class Cluster < Base
    class PidFile
      FN = 'server_cluster.pid'
    
      def self.delete
        FileUtils.rm(FN) if File.file?(FN)
      end
    
      def self.store_pid(pid)
        File.open(FN, 'a') {|f| f.puts pid}
      end
    
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

    def self.fork_server(port)
      fork do
        trap('TERM') {exit}
        server_loop(port)
      end
    end
  
    def self.start_servers
      PidFile.delete
      ports.each do |p|
        PidFile.store_pid(fork_server(p))
      end
    end
  
    def self.stop_servers
      pids = PidFile.recall_pids
      pids.each {|pid| begin; Process.kill('TERM', pid); rescue; end}
      PidFile.delete
    end
  
    def self.daemon_loop
      loop {sleep 60}
    end
  
    def self.start
      start_servers
      daemon_loop
    end
  
    def self.stop
      stop_servers
    end
  end
end
