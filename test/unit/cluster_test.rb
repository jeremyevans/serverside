require File.dirname(__FILE__) + '/../test_helper'
require 'fileutils'

class ClusterTest < Test::Unit::TestCase
  FN = Daemon::Cluster::PidFile::FN
  
  def test_pid_fn
    assert_equal 'serverside_cluster.pid', Daemon::Cluster::PidFile::FN
  end
  
  def test_pid_delete
    FileUtils.touch(FN)
    assert_equal true, File.file?(FN)
    Daemon::Cluster::PidFile.delete
    assert_equal false, File.file?(FN)
  end
  
  def test_pid_store_pid
    FileUtils.rm(FN) if File.file?(FN)
    Daemon::Cluster::PidFile.store_pid(1111)
    assert_equal "1111\n", IO.read(FN)
    Daemon::Cluster::PidFile.store_pid(2222)
    assert_equal "1111\n2222\n", IO.read(FN)
  end
  
  def test_pid_recall_pids
    FileUtils.rm(FN) if File.file?(FN)
    assert_raise(Errno::ENOENT) {Daemon::Cluster::PidFile.recall_pids}
    File.open(FN, 'w') {|f| f.puts 3333; f.puts 4444}
    assert_equal [3333, 4444], Daemon::Cluster::PidFile.recall_pids
    
    FileUtils.rm(FN)
    Daemon::Cluster::PidFile.store_pid(6666)
    Daemon::Cluster::PidFile.store_pid(7777)
    assert_equal [6666, 7777], Daemon::Cluster::PidFile.recall_pids
  end
  
  class DummyCluster < Daemon::Cluster
    FN = 'result'
    
    def self.server_loop(port)
      at_exit {File.open(FN, 'a') {|f| f.puts port}}
      loop {sleep 60}
    end
    
    def self.ports
      5555..5556
    end
  end
  
  def test_fork_server
    FileUtils.rm(DummyCluster::FN) if File.file?(DummyCluster::FN)
    pid = DummyCluster.fork_server(1111)
    sleep 1
    Process.kill('TERM', pid)
    sleep 0.1
    assert_equal true, File.file?(DummyCluster::FN)
    File.open(DummyCluster::FN, 'r') do |f|
      assert_equal 1111, f.gets.to_i
      assert_equal true, f.eof?
    end
    FileUtils.rm(DummyCluster::FN) if File.file?(DummyCluster::FN)
  end
  
  def test_start_servers
    FileUtils.rm(DummyCluster::FN) if File.file?(DummyCluster::FN)
    DummyCluster.start_servers
    sleep 0.5
    pids = Daemon::Cluster::PidFile.recall_pids
    assert_equal 2, pids.length
    pids.each {|pid| Process.kill('TERM', pid)}
    sleep 0.5
    File.open(DummyCluster::FN, 'r') do |f|
      p1, p2 = f.gets.to_i, f.gets.to_i
      assert_equal true, DummyCluster.ports.include?(p1)
      assert_equal true, DummyCluster.ports.include?(p2)
      assert p1 != p2
      assert_equal true, f.eof?
    end
    FileUtils.rm(DummyCluster::FN) if File.file?(DummyCluster::FN)
  end
  
  def test_stop_servers
    DummyCluster.start_servers
    sleep 0.5
    pids = Daemon::Cluster::PidFile.recall_pids
    DummyCluster.stop_servers
    sleep 0.5
    assert_equal false, File.file?(FN)
    File.open(DummyCluster::FN, 'r') do |f|
      p1, p2 = f.gets.to_i, f.gets.to_i
      assert_equal true, DummyCluster.ports.include?(p1)
      assert_equal true, DummyCluster.ports.include?(p2)
      assert p1 != p2
      assert_equal true, f.eof?
    end
    FileUtils.rm(DummyCluster::FN) if File.file?(DummyCluster::FN)
  end
  
  class DummyCluster2 < Daemon::Cluster
    def self.daemon_loop
      @@a = true
    end
    
    def self.start_servers
      @@b = true
    end
    
    def self.stop_servers
      @@c = true
    end
    
    def self.a; @@a; end
    def self.b; @@b; end
    def self.c; @@c; end
  end
  
  def test_start
    DummyCluster2.start
    assert_equal true, DummyCluster2.a
    assert_equal true, DummyCluster2.b
    
    DummyCluster2.stop
    assert_equal true, DummyCluster2.c
  end
  
  def test_stop
  end
end
