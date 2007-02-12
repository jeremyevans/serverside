require File.join(File.dirname(__FILE__), '../lib/serverside')
require 'stringio'
require 'fileutils'

class ServerSide::Template
  def self.templates
    @@templates
  end
  
  def self.reset
    @@templates = {}
  end
end

class IO
  def self.write(fn, content)
    File.open(fn, 'w') {|f| f << content}
  end
end

include ServerSide

context "ServerSide::Template.set" do
  specify "should add an consisting of stamp and template to the templates hash" do
    Template.reset
    Template.templates.should_be_empty
    t = Time.now
    Template.set('test', 'hello', t)
    Template.templates.include?('test').should_be true
    a = Template.templates['test']
    a.should_be_a_kind_of Array
    a.size.should == 2
    a.first.should_be t
    a.last.should_be_a_kind_of Erubis::Eruby
  end
  
  specify "should set stamp to nil by default" do
    Template.set('test', 'hello')
    Template.templates['test'].first.should_be_nil
  end
  
  specify "should construct a new Erubis::Eruby instance with the body" do
    Template.set('test', 'yo')
    Template.templates['test'].last.result(binding).should == 'yo'
  end
end

context "ServerSide::Template.validate" do
  specify "should return nil for a non-existant template" do
    Template.reset
    Template.validate('test').should_be_nil
    Template.validate('invalid_file_ref').should_be_nil
  end
  
  specify "should load a file as template if the name references a file" do
    Template.reset
    t = Template.validate(__FILE__)
    t.should_be_a_kind_of Erubis::Eruby
    t.result(binding).should == IO.read(__FILE__)
    Template.templates.size.should == 1
    t = Template.templates[__FILE__]
    t.first.should == File.mtime(__FILE__)
    t.last.should_be_a_kind_of Erubis::Eruby
  end
  
  specify "should return the Erubis::Eruby instance for an existing template" do
    Template.reset
    t = Template.validate(__FILE__)
    t.should_be_a_kind_of Erubis::Eruby
    t.result(binding).should == IO.read(__FILE__)
  end
  
  specify "should reload a file if its stamp changed" do
    Template.reset
    IO.write('tmp', '1')
    Template.validate('tmp').result(binding).should == '1'
    Template.templates['tmp'].first.should == File.mtime('tmp')
    sleep 1.5
    IO.write('tmp', '2')
    Template.validate('tmp').result(binding).should == '2'
    Template.templates['tmp'].first.should == File.mtime('tmp')
    FileUtils.rm('tmp')
  end
  
  specify "should return nil and clear the cache if a cached file has been deleted" do
    Template.reset
    IO.write('tmp', '1')
    Template.validate('tmp').result(binding).should == '1'
    Template.templates['tmp'].first.should == File.mtime('tmp')
    FileUtils.rm('tmp')
    Template.validate('tmp').should_be_nil
    Template.templates['tmp'].should_be_nil
  end
end

context "ServerSide::Template.render" do
  specify "should raise a RuntimeError for an invalid template" do
    Template.reset
    proc {Template.render('invalid', binding)}.should_raise RuntimeError
  end
  
  specify "should render an existing ad-hoc template" do
    Template.reset
    Template.set('test', 'hello there')
    Template.render('test', binding).should == 'hello there'
  end
  
  specify "should render a file-based template" do
    Template.reset
    Template.render(__FILE__, binding).should == IO.read(__FILE__)
  end
  
  specify "should validate a file-based template by checking its stamp" do
    Template.reset
    IO.write('tmp', '1')
    Template.render('tmp', binding).should == '1'
    sleep 1.5
    IO.write('tmp', '2')
    Template.render('tmp', binding).should == '2'
    FileUtils.rm('tmp')
  end
  
  specify "should pass the binding to the Erubis::Eruby instance for processing" do
    @x = 23
    Template.reset
    Template.set('test', '<' + '%= @x %' + '>')
    Template.render('test', binding).should == '23'
  end
end
