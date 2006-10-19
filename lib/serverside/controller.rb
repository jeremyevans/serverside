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
    
    def initialize(request)
      @request = request
      @path = request.path
      @parameters = request.parameters
      process
      render_default if not @rendered
    end
    
    def process
    end
    
    def render_default
      @request.send_response(200, 'text/plain', 'no response.')
    end
    
    def render(body, content_type)
      @request.send_response(200, content_type, body)
      @rendered = true
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
      controller = Inflector.underscore($1) 
      {:path => ["/#{controller}/:action", "/#{controller}/:action/:id"]}
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
