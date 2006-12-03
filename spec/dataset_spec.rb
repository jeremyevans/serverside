require File.join(File.dirname(__FILE__), '../lib/serverside')

class ServerSide::Dataset
  attr_accessor :db, :opts
end

context "The Dataset Class" do
  specify "should include the Enumerable mix-in" do
    ServerSide::Dataset.included_modules.should_include Enumerable
  end
end

context "A new Dataset instance" do
  specify "should store db and opts in @db and @opts" do
    db = "my db"
    opts = [1, 2, 3, 4]
    
    d = ServerSide::Dataset.new(db, opts)
    d.db.should_be db
    d.opts.should_be opts
  end
  
  specify "should set opts to empty hash if ommited" do
    ServerSide::Dataset.new(:db).opts.should == {}
  end
end

context "Dataset#dup_merge" do
  specify "should create a new instance of the same class with merged opts" do
    subclass = Class.new(ServerSide::Dataset)
    db = "my db"
    orig = subclass.new(db, {1 => 2, 3 => 4})
    dup = orig.dup_merge({3 => 5})
    
    dup.class.should_be subclass
    dup.opts.should == {1 => 2, 3 => 5}
    dup.db.should_be db
  end
end

context "Dataset#field_name" do
  setup {@d = ServerSide::Dataset.new(:db)}

  specify "should return the argument as is if not a symbol" do
    @d.field_name(nil).should == nil
    @d.field_name(1).should == 1
    @d.field_name('field').should == 'field'
  end
  
  specify "should parse fields with underscore without change" do
    @d.field_name(:node_id).should == 'node_id'
  end
  
  specify "should parse double-underscore as dot-notation" do
    @d.field_name(:posts__id).should == 'posts.id'
  end
  
  specify "should parse triple-underscore as AS notation" do
    @d.field_name(:posts__id___pid).should == 'posts.id AS pid'
  end
end

context "Dataset#field_list" do
  setup {@d = ServerSide::Dataset.new(:db)}

  specify "should return the sql wildcard if an empty array is specified" do
    @d.field_list([]).should == '*'
  end
  
  specify "should return comma-separated field list if an array is passed" do
    @d.field_list([:a, :b]).should == 'a, b'
  end
  
  specify "should return the argument as is if not an array" do
    @d.field_list(nil).should_be_nil
    @d.field_list(23).should_be 23
    @d.field_list("wowie zowie").should == "wowie zowie"
  end
  
  specify "should parse field names using #field_name" do
    @d.field_list([:posts__author_id, :authors__name]).should ==
      'posts.author_id, authors.name'
    
    @d.field_list([:posts__id___pid, :authors__name___aname]).should ==
      'posts.id AS pid, authors.name AS aname'
  end
end

context "Dataset#source_list" do
  setup {@d = ServerSide::Dataset.new(:db)}

  specify "should return the argument if not an array or hash" do
    @d.source_list(nil).should_be_nil
    @d.source_list(1).should == 1
    @d.source_list('hello').should == 'hello'
    @d.source_list(:symbol).should == :symbol
  end
  
  specify "should return comma-separated value if an array is specified" do
    @d.source_list([1, 2, 3]).should == '1, 2, 3'
  end
end

context "Dataset DSL: " do
  specify "#form should create a duplicate dataset with the source argument merged" do
    subclass = Class.new(ServerSide::Dataset)
    d1 = subclass.new(:db, {:select => '*'})
    
    d2 = d1.from(:posts)
    d2.class.should_be subclass
    d2.opts[:select].should == '*'
    d2.opts[:from].should == :posts
  end 

  specify "#select should create a duplicate dataset with the select argument merged" do
    subclass = Class.new(ServerSide::Dataset)
    d1 = subclass.new(:db, {:from => :posts})
    
    d2 = d1.select(:id, :name)
    d2.class.should_be subclass
    d2.opts[:from].should == :posts
    d2.opts[:select].should == [:id, :name]
  end 
end
