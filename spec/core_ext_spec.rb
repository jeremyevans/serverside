require File.join(File.dirname(__FILE__), '../lib/serverside')

# String extensions

context "String" do
  specify "should have URI escaping functionality" do
    'a b c'.uri_escape.should == 'a+b+c'
    'a/b#1@6%8K'.uri_escape.should == 'a%2Fb%231%406%258K'
  end
  
  specify "should have URI unescaping functionality" do
    'a%20b%20c'.uri_unescape.should == 'a b c'
    'a%2Fb%231%406%258K'.uri_unescape.should == 'a/b#1@6%8K'
    s = 'b!-=&*%aAåabéfak{}":,m"\'Mbac( 12313t awerqwe)'
    s.uri_escape.uri_unescape.should == s
  end

  specify "should have a / operator for joining paths." do
    ('abc'/'def').should == 'abc/def'
    ('/hello/'/'there').should == '/hello/there'
    ('touch'/'/me/'/'hold'/'/me').should == 'touch/me/hold/me'
  end
  
  specify ".underscore should turn camel-cased phrases to underscored ones" do
    'CamelCase'.underscore.should == 'camel_case'
    'Content-Type'.underscore.should == 'content_type'
  end
end

# Symbol extensions

class Symbol
  attr_reader :_to_s
end

context "Symbol.to_s" do
  specify "should convert the symbol to a string" do
    :abc_def.to_s.should == 'abc_def'
    :def_ghi.to_s.should_be_instance_of String
    :ghi_jkl.to_s.should == :ghi_jkl.id2name
  end
  
  specify "should cache the id2name value" do
    :kwantz_mit_krantz._to_s.should_be_nil
    :kwantz_mit_krantz.to_s
    :kwantz_mit_krantz._to_s.should == :kwantz_mit_krantz.id2name
  end
  
  specify "should always return the same cached value" do
    :item.to_s.should_be :item.to_s
  end
end

context "Proc.proc_tag" do
  setup do
    @l1 = lambda {1 + 1}
    @l2 = lambda {1 + 1}
  end
  
  specify "should return a unique tag for the proc object" do
    @l1.proc_tag.should_not_equal @l2.proc_tag
  end
 
  specify "should return the same tag always" do
    @l1.proc_tag.should == @l1.proc_tag
  end
  
  specify "should return the object id in base 36 prefixed with 'proc_'" do
    @l1.proc_tag.should == 'proc_' + @l1.object_id.to_s(36).sub('-', '_')
  end
end

context "Object.const_tag" do
  setup do
    @o1 = Object.new
    @o2 = Object.new
  end

  specify "should return a unique tag for the object" do
    @o1.const_tag.should_not_equal @o2.const_tag
  end
  
  specify "should return the same tag always" do
    @o1.const_tag.should == @o1.const_tag
    @o2.const_tag.should == @o2.const_tag
  end
  
  specify "should return the object id in base 36 (upcase) prefixed with 'C'" do
    @o1.const_tag.should == 'C' + @o1.object_id.to_s(36).upcase.sub('-', '_')
    @o2.const_tag.should == 'C' + @o2.object_id.to_s(36).upcase.sub('-', '_')
  end
end