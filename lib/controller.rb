#require_all 'lib/controller'
require 'rubygems'
require 'metaid'

module Controller
  class Router
    class << self
      attr_accessor :rules
      
      def add_rule(rule, proc = nil, &block)
        @rules ||= []
        @rules.unshift([compile_rule(rule), proc || block])
      end
      
      def compile_rule(rule)
        if rule[:path].kind_of?(String)
          Proc.new {|req|req[:path] =~ Regexp.new(rule[:path])}
        else
          Proc.new {|req|req[:path] =~ rule[:path]}
        end
      end
      
      def route(req)
        @rules ||= []
        @rules.each do |r|
          if r[0].call(req)
            r[1].call(req)
            return
          end
        end
        nil
      end
    end
  end
  
  class Base
    def process(req)
      puts self.class
    end
  end
  
  def self.mount(rule)
    Class.new(Base) {
      meta_def(:rule) {rule}
      meta_def(:inherited) {|c|Router.add_rule(c.rule, Proc.new{|req|c.new.process(req)})}
    }
  end
end

class DefaultController < Controller.mount(:path => '/')
end

class HelpController < Controller.mount(:path => '^/help')
end
