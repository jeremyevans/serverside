require 'fileutils'

# The Daemon module takes care of starting and stopping daemons.
module Daemon
  WorkingDirectory = FileUtils.pwd

  class Base
    def self.pid_fn
      File.join(WorkingDirectory, "#{name.gsub('::', '.').downcase}.pid")
    end
  end
  
  # Stores and recalls the daemon pid.
  module PidFile
    # Stores the daemon pid.
    def self.store(daemon, pid)
      File.open(daemon.pid_fn, 'w') {|f| f << pid}
    end
    
    # Recalls the daemon pid. If the pid can not be recalled, an error is 
    # raised.
    def self.recall(daemon)
      IO.read(daemon.pid_fn).to_i
    rescue
      raise 'Pid not found. Is the daemon started?'
    end
    
    def self.remove(daemon)
      FileUtils.rm(daemon.pid_fn) if File.file?(daemon.pid_fn)
    end
  end
  
  # Controls a daemon according to the supplied command or command-line 
  # parameter. If an invalid command is specified, an error is raised.
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
  
  # Starts the daemon by forking and bcoming session leader.
  def self.start(daemon)
    fork do
      Process.setsid
      exit if fork
      PidFile.store(daemon, Process.pid)
      Dir.chdir WorkingDirectory
      File.umask 0000
#      STDIN.reopen "/dev/null"
#      STDOUT.reopen "/dev/null", "a"
#      STDERR.reopen STDOUT
      trap("TERM") {daemon.stop; exit}
      daemon.start
    end
  end
  
  # Stops the daemon by sending it a TERM signal.
  def self.stop(daemon)
    pid = PidFile.recall(daemon)
    pid && Process.kill("TERM", pid) rescue nil
    PidFile.remove(daemon)
  end

  def self.alive?(daemon)
    pid = PidFile.recall(daemon) rescue nil
    return nil if !pid
    `ps #{pid}` =~ /#{pid}/ ? true : nil
  end
end
