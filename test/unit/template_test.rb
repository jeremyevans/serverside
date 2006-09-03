require File.dirname(__FILE__) + '/../test_helper'
require 'stringio'
require 'fileutils'

class ServerSide::Template
  def self.reset
    @@templates = {}
  end

  def self.templates
    @@templates
  end
end

class TemplateTest < Test::Unit::TestCase
  def test_set
    ServerSide::Template.reset
    assert_equal 0, ServerSide::Template.templates.size
    ServerSide::Template.set('sharon', 'Hello chilren!')
    assert_equal 1, ServerSide::Template.templates.size
    assert_equal ['sharon'], ServerSide::Template.templates.keys
    t = ServerSide::Template.templates['sharon']
    assert_kind_of Array, t
    assert_equal nil, t[0]
    assert_kind_of ERB, t[1]
    assert_equal 'Hello chilren!', t[1].result(binding)
    
    stamp = Time.now - 100
    ServerSide::Template.set('zohar', 'FSMV <%= wow %>', stamp)
    assert_equal 2, ServerSide::Template.templates.size
    assert_equal true, ServerSide::Template.templates.keys.include?('zohar')
    t = ServerSide::Template.templates['zohar']
    assert_kind_of Array, t
    assert_equal stamp, t[0]
    assert_kind_of ERB, t[1]
    wow = 'wow'
    assert_equal 'FSMV wow', t[1].result(binding)
  end
  
  def test_render
    ServerSide::Template.reset
    assert_raise(RuntimeError) {ServerSide::Template.render('sharon', binding)}

    ServerSide::Template.set('sharon', 'Hello <%= name %>!')
    name = 'world'
    assert_equal 'Hello world!', ServerSide::Template.render('sharon', binding)
  end
  
  FN = 'test.rhtml'
  HtmlTemplate = "<% cats.each do |name| %><li><%= name %></li><% end %>"
    
  def teardown
    FileUtils.rm(FN) if File.file?(FN)
  end
  
  def test_render_file
    FileUtils.rm(FN) if File.file?(FN)
    assert_raise(RuntimeError) {ServerSide::Template.render(FN, binding)}

    File.open(FN, 'w') {|f| f << HtmlTemplate}
    assert_raise(NoMethodError) {ServerSide::Template.render(FN, binding)}
    
    cats = %w{Ciconia Marie Tipa}
    s = ServerSide::Template.render(FN, binding)
    assert_equal "<li>Ciconia</li><li>Marie</li><li>Tipa</li>", s
    
    cats = []
    s = ServerSide::Template.render(FN, binding)
    assert_nil s.match('<li>')
    
    sleep 2
    
    cats = %w{Ciconia Marie Tipa}
    File.open(FN, 'w') {|f| f << "<%= cats.join(', ') %>"}
    
    assert_equal 'Ciconia, Marie, Tipa', ServerSide::Template.render(FN, binding)
  end  
end
