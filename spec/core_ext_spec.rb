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
  
  specify "#underscore should turn camel-cased phrases to underscored ones" do
    'CamelCase'.underscore.should == 'camel_case'
    'Content-Type'.underscore.should == 'content_type'
  end
  
  specify "#camelize should turn an underscore name to camelcase" do
    'wowie_zowie'.camelize.should == 'WowieZowie'
  end
end

context "Process.exists?" do
  specify "should return false for a non-existing process" do
    # bogus pid   
    pid = nil
    while pid = rand(10000)
      break if `ps #{pid}` !~ /#{pid}/
    end
    Process.exists?(pid).should be_false
  end
  
  specify "should return true for an existing process" do
    Process.exists?(Process.pid).should be_true
  end
end
