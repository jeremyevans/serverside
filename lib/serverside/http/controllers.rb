require File.join(File.dirname(__FILE__), 'routing')
require 'rubygems'
require 'metaid'

module ServerSide
  # Implements a basic controller class for handling requests. Controllers can
  # be mounted by using the Controller.mount  
  class Controller
    # Creates a subclass of Controller which adds a routing rule when 
    # subclassed. For example:
    #
    #   class MyController < ServerSide::Controller.mount('/ohmy')
    #     def response
    #       render('Hi there!', 'text/plain')
    #     end
    #   end
    #
    # You can of course route according to any rule as specified in
    # ServerSide::Router.route, including passing a block as a rule, e.g.:
    #
    #   class MyController < ServerSide::Controller.mount {@headers['Accept'] =~ /wap/}
    #     ...
    #   end
    def self.mount(rule = nil, &block)
      rule ||= block
      raise ArgumentError, "No routing rule specified." if rule.nil?
      Class.new(self) do
        meta_def(:inherited) do |sub_class|
          ServerSide::Router.route(rule) {sub_class.new(self)}
        end
      end
    end
    
    # Initialize a new controller instance. Sets @request to the request object
    # and copies both the request path and parameters to instance variables.
    # After calling response, this method checks whether a response has been sent
    # (rendered), and if not, invokes the render_default method. 
    def initialize(request)
      @request = request
      @path = request.path
      @parameters = request.parameters
      response
      render_default if not @rendered
    end
    
    # Renders the response. This method should be overriden.
    def response
    end
    
    # Sends a default response.
    def render_default
      @request.send_response(200, 'text/plain', 'no response.')
    end
    
    # Sends a response and sets @rendered to true.
    def render(body, content_type)
      @request.send_response(200, content_type, body)
      @rendered = true
    end
  end
end

