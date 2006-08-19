require 'fileutils'

module Daemon
  WorkingDirectory = FileUtils.pwd

  class Base
    def self.pid_fn
      File.join(WorkingDirectory, "#{name.gsub('::', '.').downcase}.pid")
    end
  end
  
  module PidFile
    def self.store(daemon, pid)
      File.open(daemon.pid_fn, 'w') {|f| f << pid}
    end
    
    def self.recall(daemon)
      IO.read(daemon.pid_fn).to_i
    rescue
      raise 'Pid not found. Is the daemon started?'
    end
  end
  
  def self.control(daemon, cmd = nil)
    case (cmd || (!ARGV.empty? && ARGV[0]) || :nil).to_sym
    when :start
      start(daemon)
    when :stop
      stop(daemon)
    when :restart
      stop(daemon)
      start(daemon)
    else
      raise 'Invalid command. Please specify start, stop or restart.'
    end
  end
  
  def self.start(daemon)
    fork do
      Process.setsid
      exit if fork
      PidFile.store(daemon, Process.pid)
      Dir.chdir WorkingDirectory
      File.umask 0000
      STDIN.reopen "/dev/null"
      #STDOUT.reopen "/dev/null", "a"
      #STDERR.reopen STDOUT
      trap("TERM") {daemon.stop; exit}
      daemon.start
    end
  end

  def self.stop(daemon)
    pid = PidFile.recall(daemon)
    FileUtils.rm(daemon.pid_fn)
    pid && Process.kill("TERM", pid)
  end
end
