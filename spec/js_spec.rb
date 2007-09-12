require File.join(File.dirname(__FILE__), 'spec_helper')

context "A new JS representation" do
  specify "should work with no arguments" do
    js = ServerSide::JS.new
    js.to_s.should == 'null'
    
    js.abc 123
    js.to_s.should == '{"abc":123}'
  end
  
  specify "should accept a callback" do
    js = ServerSide::JS.new('fn')
    js.to_s.should == 'fn(null);'
  end

  specify "should accept a block and run it" do
    js = ServerSide::JS.new do |j|
      j.abc  123
    end
    js.to_s.should == '{"abc":123}'
  end
end

context "JS instance methods" do
  setup do
    @js = ServerSide::JS.new
  end
  
  specify "should accept strings" do
    @js.x 'zzz'
    @js.to_s.should == '{"x":"zzz"}'
  end
  
  specify "should accept numbers" do
    @js.x 3
    @js.to_s.should == '{"x":3}'
    
    @js = ServerSide::JS.new
    @js.x 4.5
    @js.to_s.should == '{"x":4.5}'
  end
  
  specify "should accept true, false, nil" do
    @js.x true
    @js.to_s.should == '{"x":true}'
    
    @js = ServerSide::JS.new
    @js.x false
    @js.to_s.should == '{"x":false}'

    @js = ServerSide::JS.new
    @js.x nil
    @js.to_s.should == '{"x":null}'
  end
  
  specify "should accept arrays" do
    @js.x [1, 2, 3]
    @js.to_s.should == '{"x":[1,2,3]}'
  end

  specify "should accept blocks" do
    @js.x {|j| j.y 'hello'}
    @js.to_s.should == '{"x":{"y":"hello"}}'
  end
  
  specify "should support << operator" do
    @js << 1
    @js << 2
    @js.to_s.should == '[1,2]'

    @js = ServerSide::JS.new
    @js.xxx {|j| j << 1 << 2}
    @js.to_s.should == '{"xxx":[1,2]}'
  end
  
  specify "should accept JS objects" do
    @js.y [1, 2, 3, 4]
    
    @outer = ServerSide::JS.new do |j|
      j.x @js
    end
    
    @outer.to_s.should == '{"x":{"y":[1,2,3,4]}}'
  end
end