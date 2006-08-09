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
        return rule if rule.kind_of?(Proc)
        
        tmp_rule = rule.clone
        tmp_rule.each do |k, v|
          tmp_rule[k] = Regexp.new(v) if v.kind_of?(String)
        end
        Proc.new do |req|
          match = true
          tmp_rule.each {|k, v| match &&= req[k] =~ v}
          match
        end
      end
      
      def route(req)
        @rules ||= []
        @rules.each do |r|
          if r[0].call(req)
            r[1].call(req)
            return true
          end
        end
        nil
      end
    end
  end
  
  def self.mount(rule = nil, &block)
    Class.new(Base) do
      meta_def(:rule) {rule || block}
      meta_def(:inherited) do |c|
        Router.add_rule(c.rule, Proc.new{|req|c.new.process(req)})
      end
    end
  end
end
