require File.join(File.dirname(__FILE__), '../lib/serverside')

class TestDaemon < Daemon::Base
  def self.start
    @count = 0
    loop {@count += 1; sleep 0.1}
    puts "finished"
  end
  
  def self.result_fn
    File.join(Daemon::WorkingDirectory, 'test.result')
  end
  
  def self.stop
    #File.open(result_fn, 'w') {|f| f << @count}
  end
end

context "Daemon::WorkingDirectory" do
  specify "should be the working directory (pwd)" do
    Daemon::WorkingDirectory.should == FileUtils.pwd
  end
end

context "Daemon::Base.pid_fn" do
  specify "should construct the pid_fn according to the class name" do
    Daemon::Base.pid_fn.should == 
      File.join(Daemon::WorkingDirectory, 'daemon.base.pid')

    TestDaemon.pid_fn.should == 
      File.join(Daemon::WorkingDirectory, 'testdaemon.pid')
  end
end

context "Daemon::PidFile" do
  specify "should store the pid in a file" do
    pid = rand(1_000_000)
    Daemon::PidFile.store(TestDaemon, pid)
    File.file?(TestDaemon.pid_fn).should == true
    IO.read(TestDaemon.pid_fn).should == pid.to_s
    Daemon::PidFile.remove(TestDaemon)
  end
  
  specify "should recall the pid from the pid file" do
    pid = rand(1_000_000)
    Daemon::PidFile.store(TestDaemon, pid)
    Daemon::PidFile.recall(TestDaemon).should == pid
    Daemon::PidFile.recall(TestDaemon).should_be_a_kind_of Fixnum
    Daemon::PidFile.remove(TestDaemon)
  end
  
  specify "should raise an exception if can't recall pid" do
    Daemon::PidFile.remove(TestDaemon) # make sure the file doesn't exist
    proc {Daemon::PidFile.recall(TestDaemon)}.should_raise
  end
  
  specify "should remove the pid file" do
    File.file?(TestDaemon.pid_fn).should == false
    Daemon::PidFile.store(TestDaemon, 1024)
    File.file?(TestDaemon.pid_fn).should == true
  end
end

context "Daemon.control" do
  teardown {Daemon.control(TestDaemon, :stop) rescue nil}
  
  specify "should start and stop the daemon" do
    Daemon::PidFile.remove(TestDaemon)
    Daemon.control(TestDaemon, :start)
    sleep 0.2
    File.file?(TestDaemon.pid_fn).should == true
    sleep 0.5
    proc {Daemon::PidFile.recall(TestDaemon)}.should_not_raise
    Daemon.control(TestDaemon, :stop)
    sleep 0.2
    File.file?(TestDaemon.result_fn).should == false
  end
  
  specify "should restart the daemon" do
    Daemon::PidFile.remove(TestDaemon)
    Daemon.control(TestDaemon, :start)
    begin
      sleep 1
      pid1 = Daemon::PidFile.recall(TestDaemon)
      Daemon.control(TestDaemon, :restart)
      sleep 1
      pid2 = Daemon::PidFile.recall(TestDaemon)
      pid1.should_not == pid2
    ensure
      Daemon.control(TestDaemon, :stop)
      Daemon::PidFile.remove(TestDaemon)
    end
  end
  
  specify "should raise RuntimeError for invalid command" do
    proc {Daemon.control(TestDaemon, :invalid)}.should_raise
  end
end

context "Daemon.alive?" do
  teardown {Daemon.control(TestDaemon, :stop) rescue nil}
  
  specify "should return nil if not running" do
    Daemon.alive?(TestDaemon).should_be_nil
  end
  
  # specify "should return true if running" do
  #   Daemon.control(TestDaemon, :start)
  #   sleep 0.2
  #   Daemon.alive?(TestDaemon).should_be true
  #   sleep 0.5
  #   Daemon.control(TestDaemon, :stop)
  #   sleep 0.2
  #   Daemon.alive?(TestDaemon).should_be_nil
  # end
  
  # specify "should return nil if the daemon process is killed" do
  #   Daemon.control(TestDaemon, :start)
  #   sleep 1
  #   pid = Daemon::PidFile.recall(TestDaemon)
  #   Daemon.alive?(TestDaemon).should_be true
  #   Process.kill("TERM", pid)
  #   sleep 1
  #   Daemon.alive?(TestDaemon).should_be_nil
  #   Daemon.control(TestDaemon, :stop)
  # end
end

