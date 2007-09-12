require File.join(File.dirname(__FILE__), 'spec_helper')

context "A new XML representation" do
  specify "should work with no arguments" do
    xml = ServerSide::XML.new
    xml.to_s.should == ''
    
    xml.abc
    xml.to_s.should == '<abc></abc>'
  end
  
  specify "should accept a tag name" do
    xml = ServerSide::XML.new('def')
    xml.to_s.should == '<def></def>'
  end

  specify "should accept attributes" do
    xml = ServerSide::XML.new('a', :href => '/hello/dolly')
    xml.to_s.should == '<a href="/hello/dolly"></a>'
  end
  
  specify "should accept a block and run it" do
    xml = ServerSide::XML.new do |x|
      x.abc do
        x.def 123
      end
    end
    xml.to_s.should == '<abc><def>123</def></abc>'
  end
end

context "XML#instruct!" do
  setup do
    @xml = ServerSide::XML.new
  end
  
  specify "should add an XML instruction" do
    @xml.instruct!
    @xml.to_s.should =~ /^\<\?xml(.+)\?\>$/

    @xml.to_s.should =~ /\s#{'version="1.0"'}/
    @xml.to_s.should =~ /\s#{'encoding="UTF-8"'}/
  end
  
  specify "should accept attributes" do
    @xml.instruct!(:something => 'XXX')
    @xml.to_s.should == '<?xml something="XXX"?>'
  end
end

context "XML instance methods" do
  setup do
    @xml = ServerSide::XML.new
  end
  
  specify "should escape values" do
    @xml.x "&\"><"
    @xml.to_s.should == "<x>&amp;&quot;&gt;&lt;</x>"
  end
  
  specify "should accept attributes" do
    @xml.x({:z => '123'}, '')
    @xml.to_s.should == '<x z="123"></x>'

    @xml = ServerSide::XML.new
    @xml.x({:z => '123'}, 'yyy')
    @xml.to_s.should == '<x z="123">yyy</x>'
  end
  
  specify "should support subtags" do
    h = {:name => 'abc', :category => 'def'}
    @xml.item [:category, :name], h
    @xml.to_s.should == '<item><category>def</category><name>abc</name></item>'
  end
end