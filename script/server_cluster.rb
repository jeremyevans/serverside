ENV['ENVIRONMENT'] = 'production'

require File.join(File.dirname(__FILE__), 'daemon')
require 'fileutils'

class ServerDaemon < Daemon::Base
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
#      require 'lib/server'
#      Reality::Model.connect(:production)
#      server = Mongrel::HttpServer.new('0.0.0.0', port)
#      server.register('/', RealityMongrelHandler.new('../static'))
#      periodically(60) {server.reap_dead_workers}
      trap('TERM') {exit}
#      server.run.join
      loop do
        sleep(1)
      end
    end
  end
  
  def self.start_servers
    PidFile.delete
    ports = $config[:server_ports] || (8000..8000)
    ports.each do |p|
      PidFile.store_pid(fork_server(p))
    end
  end
  
  def self.stop_servers
    pids = PidFile.recall_pids
    pids.each {|pid| begin; Process.kill('TERM', pid); rescue; end}
    PidFile.delete
  end
  
  def self.start
    require '../config/boot'
    start_servers
#    Reality::Model.connect(:production)
    loop do
#      Channel.destroy_stale_channels
#      Session.remove_expired_sessions
      sleep(60)
    end
  end
  
  def self.stop
    stop_servers
  end
end
