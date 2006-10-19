require File.join(File.dirname(__FILE__), 'routing')

module ServerSide
  class Controller
    def self.mount(rule = nil, &block)
      rule ||= block
      raise ArgumentError, "No routing rule specified." if rule.nil?
      c = Class.new(self) {}
      ServerSide::Router.route(rule) {c.new(self)}
      c
    end
  end
end

__END__

require 'rubygems'
require 'active_support/inflector'
require 'metaid'

class ActionController
  def self.default_routing_rule
    if name.split('::').last =~ /(.+)Controller$/
      {:path => ''/Inflector.underscore($1)}
    end
  end

  def self.inherited(c)
    routing_rule = c.respond_to?(:routing_rule) ?
      c.routing_rule : c.default_routing_rule
    if routing_rule
      ServerSide::Router.route(routing_rule) {c.new(self)}
    end
  end
  
  def self.route(arg = nil, &block)
    rule = arg || block
    meta_def(:get_route) {rule}
  end
end

class MyController < ActionController
  route "hello"
end

p MyController.get_route
