require File.join(File.dirname(__FILE__), 'routing')

module ServerSide
  class Controller
    def self.mount(rule)
      c = Class.new(self) {}
      ServerSide::Router.route(rule) {c.new(self)}
      c
    end
  end
end
