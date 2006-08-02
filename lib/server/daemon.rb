require 'fileutils'

module Daemon
  WorkingDirectory = File.expand_path(File.dirname(__FILE__))  

  class Base
    def self.pid_fn
      File.join(WorkingDirectory, "#{name}.pid")
    end
    
    def self.daemonize
      Controller.daemonize(self)
    end
  end
  
  module PidFile
    def self.store(daemon, pid)
      File.open(daemon.pid_fn, 'w') {|f| f << pid}
    end
    
    def self.recall(daemon)
      IO.read(daemon.pid_fn).to_i rescue nil
    end
  end
  
  module Controller
    def self.daemonize(daemon)
      case !ARGV.empty? && ARGV[0]
      when 'start'
        start(daemon)
      when 'stop'
        stop(daemon)
      when 'restart'
        stop(daemon)
        start(daemon)
      else
        puts "Invalid command. Please specify start, stop or restart."
        exit
      end
    end
    
    def self.start(daemon)
      fork do
        Process.setsid # Become session leader.
        exit if fork # Zap session leader.
        PidFile.store(daemon, Process.pid) # Store the pid
        Dir.chdir WorkingDirectory # Change to working directory
        File.umask 0000 # Ensure sensible umask. Adjust as needed.
        STDIN.reopen "/dev/null" # Free file descriptors and
        #STDOUT.reopen "/dev/null", "a" # point them somewhere sensible.
        #STDERR.reopen STDOUT # STDOUT/ERR should better go to a logfile.
        trap("TERM") {daemon.stop; exit}
        daemon.start
      end
    end
  
    def self.stop(daemon)
      if !File.file?(daemon.pid_fn)
        puts "Pid file not found. Is the daemon started?"
        exit
      end
      pid = PidFile.recall(daemon)
      FileUtils.rm(daemon.pid_fn)
      pid && Process.kill("TERM", pid)
    end
  end
end
