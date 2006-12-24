require File.join(File.dirname(__FILE__), '../lib/serverside')
require File.join(File.dirname(__FILE__), '../lib/serverside/db/postgres')

context "A new Postgres::Database" do
  specify "should create a PGConn object" do
    Postgres::Database.new.conn.should_be_a_kind_of PGconn
  end
end

