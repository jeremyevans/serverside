require File.join(File.dirname(__FILE__), '../lib/serverside')

context "A new Postgres::Database" do
  specify "should create a PGConn object" do
    Postgres::Database.new.conn.should_be_a_kind_of PGconn
  end
end

