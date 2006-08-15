require File.dirname(__FILE__) + '/../test_helper'

class Daemon::Base
  def self.inherited(c)
    # do nothing
  end
end

class DaemonTest < Test::Unit::TestCase
  class TestDaemon < Daemon::Base
    def self.start
      @count = 0
      loop {@count += 1; sleep 0.1}
    end
    
    def self.result_fn
      File.join(Daemon::WorkingDirectory, 'test.result')
    end
    
    def self.stop
      File.open(result_fn, 'w') {|f| f << @count}
    end
  end

  def teardown
    Daemon.control(TestDaemon, :stop) rescue nil
  end
  
  def test_working_directory
    assert_equal FileUtils.pwd, Daemon::WorkingDirectory
  end
  
  def test_pid_fn
    assert_equal File.join(Daemon::WorkingDirectory, 'daemon.base.pid'),
      Daemon::Base.pid_fn
    
    assert_equal File.join(Daemon::WorkingDirectory, 'daemontest.testdaemon.pid'),
      TestDaemon.pid_fn
  end
  
  def test_pid_file_store
    Daemon::PidFile.store(TestDaemon, 1234)
    assert_equal IO.read(TestDaemon.pid_fn).to_i, 1234
  end
  
  def test_pid_file_recall
    FileUtils.rm(TestDaemon.pid_fn) rescue nil
    assert_raise(RuntimeError) {Daemon::PidFile.recall(TestDaemon)}
    Daemon::PidFile.store(TestDaemon, 5321)
    assert_equal 5321, Daemon::PidFile.recall(TestDaemon)
  end
  
  def test_start_stop
    FileUtils.rm(TestDaemon.result_fn) rescue nil
    Daemon.control(TestDaemon, :start)
    assert_equal true, File.file?(TestDaemon.pid_fn)
    sleep 0.5
    assert_nothing_raised {Daemon::PidFile.recall(TestDaemon)}
    Daemon.control(TestDaemon, :stop)
    sleep 0.5
    assert_equal true, File.file?(TestDaemon.result_fn)
    FileUtils.rm(TestDaemon.result_fn) rescue nil
  end
  
  def test_restart
    FileUtils.rm(TestDaemon.result_fn) rescue nil
    Daemon.control(TestDaemon, :start)
    sleep 0.5
    pid1 = Daemon::PidFile.recall(TestDaemon)
    Daemon.control(TestDaemon, :restart)
    sleep 0.5
    pid2 = Daemon::PidFile.recall(TestDaemon)
    assert pid1 != pid2
    Daemon.control(TestDaemon, :stop)
  end
  
  def test_invalid_control_cmd
    assert_raise(RuntimeError) {Daemon.control(TestDaemon, :invalid)}
  end
end
