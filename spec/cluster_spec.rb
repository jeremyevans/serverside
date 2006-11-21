require File.join(File.dirname(__FILE__), '../lib/serverside')

__END__

context "Daemon::Cluster::PidFile" do
  setup do
    @fn = Daemon::Cluster::PidFile::FN
  end

  specify "::FN should be the cluster's pid file" do
    Daemon::Cluster::PidFile::FN.should == 'serverside_cluster.pid'
  end
  
  specify "should delete the cluster's pid file" do
    FileUtils.touch(@fn)
    File.file?(@fn).should == true
    Daemon::Cluster::PidFile.delete
    File.file?(@fn).should == false
  end
  
  specify "should store multiple pids" do
    Daemon::Cluster::PidFile.delete
    Daemon::Cluster::PidFile.store_pid(1111)
    IO.read(@fn).should == "1111\n"
    Daemon::Cluster::PidFile.store_pid(2222)
    IO.read(@fn).should == "1111\n2222\n"
  end
  
  def test_pid_recall_pids
    Daemon::Cluster::PidFile.delete
    proc {Daemon::Cluster::PidFile.recall_pids}.should_raise Errno::ENOENT
    File.open(@fn, 'w') {|f| f.puts 3333; f.puts 4444}
    Daemon::Cluster::PidFile.recall_pids.should == [3333, 4444]
    
    FileUtils.rm(@fn)
    Daemon::Cluster::PidFile.store_pid(6666)
    Daemon::Cluster::PidFile.store_pid(7777)
    Daemon::Cluster::PidFile.recall_pids.should == [6666, 7777]
  end
end

class DummyCluster < Daemon::Cluster
  FN = 'result'
  
  def self.server_loop(port)
    at_exit {File.open(FN, 'a') {|f| f.puts port}}
    loop {sleep 10}
  end
  
  def self.ports
    5555..5556
  end
end

context "Cluster.fork_server" do
  specify "should fork a server on the specified port" do
    FileUtils.rm(DummyCluster::FN) rescue nil
    port = rand(5_000)
    pid = DummyCluster.fork_server(port)
    sleep 1
    Process.kill('TERM', pid)
    sleep 0.1
    File.file?(DummyCluster::FN).should == true
    File.open(DummyCluster::FN, 'r') do |f|
      f.gets.to_i.should == port
      f.eof?.should == true
    end
    FileUtils.rm(DummyCluster::FN) rescue nil
  end
end

context "Cluster.start_servers" do
  specify "should start a cluster of servers" do
    FileUtils.rm(DummyCluster::FN) rescue nil
    DummyCluster.start_servers
    sleep 0.5
    pids = Daemon::Cluster::PidFile.recall_pids
    pids.length.should == 2
    pids.each {|pid| Process.kill('TERM', pid)}
    sleep 0.5
    File.open(DummyCluster::FN, 'r') do |f|
      p1, p2 = f.gets.to_i, f.gets.to_i
      DummyCluster.ports.include?(p1).should == true
      DummyCluster.ports.include?(p2).should == true
      p1.should_not == p2
      f.eof?.should == true
    end
    FileUtils.rm(DummyCluster::FN) rescue nil
  end
end

context "Cluster.stop_servers" do
  specify "should stop the cluster of servers" do
    DummyCluster.start_servers
    sleep 0.5
    pids = Daemon::Cluster::PidFile.recall_pids
    DummyCluster.stop_servers
    sleep 0.5
    File.file?(Daemon::Cluster::PidFile::FN).should == false
    File.open(DummyCluster::FN, 'r') do |f|
      p1, p2 = f.gets.to_i, f.gets.to_i
      DummyCluster.ports.include?(p1).should == true
      DummyCluster.ports.include?(p2).should == true
      p1.should_not == p2
      f.eof?.should == true
    end
    FileUtils.rm(DummyCluster::FN) rescue nil
  end
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

context "Cluster.start and stop" do
  specify "should start and stop the cluster daemon" do
    DummyCluster2.start
    DummyCluster2.a.should == true
    DummyCluster2.b.should == true
    
    proc {DummyCluster2.c}.should_raise
    DummyCluster2.stop
    DummyCluster2.c.should == true
  end
end
  
