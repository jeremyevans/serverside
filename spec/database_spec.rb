require File.join(File.dirname(__FILE__), '../lib/serverside')


class ServerSide::Database
  attr_accessor :opts
  
  def make_connection
    :dummy_connection
  end
end

context "A new Database" do
  specify "should accept options and store them in @opts" do
    opts = :my_options
    ServerSide::Database.new(opts).opts.should_be opts
  end
  
  specify "should set opts to empty hash if not specified" do
    ServerSide::Database.new.opts.should == {}
  end
  
  specify "should call make_connection and store the result in @conn" do
    ServerSide::Database.new.conn.should == :dummy_connection
  end
end

