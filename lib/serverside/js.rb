require 'metaid'
require 'json'

module ServerSide
  # Serializes data into a Javscript literal hash format. For example:
  # ServerSide::JS.new {|j| j}
  class JS
    # blank slate
    instance_methods.each do |m|
      undef_method m unless (m =~ /^__|instance_eval|meta|respond_to|nil|is_a/)
    end
  
    # Initializes a new document. A callback function name can be supplied to
    # wrap the hash.
    def initialize(callback = nil, &block)
      @callback = callback
      @stack = [self]
      block.call(self) if block
    end
    
    # Catches calls to define keys and creates methods on the fly.
    def method_missing(key, *args, &block)
      value = nil
      if block
        @stack.push JS.new
        block.call(self)
        value = @stack.pop.__content
      else
        value = args.first
        value = value.__content if value.respond_to?(:__content)
      end
      
      if key == :__item
        @stack.last.__add_array_value(value)
      else
        @stack.last.__add_hash_value(key, value)
      end
      self
    end
    
    def __add_hash_value(key, value)
      @content ||= {}
      @content[key] = value
    end
    
    def __add_array_value(value)
      @content ||= []
      @content << value
    end
    
    def <<(value)
      value = value.__content if value.respond_to?(:__content)
      @stack.last.__add_array_value(value)
    end
    
    # Returns the current document content.
    def __content
      @content
    end
    
    NULL = 'null'.freeze
    
    # Serializes the specified object into JS/JSON format. 
    def __serialize(obj)
      case obj
      when Time: JSON.generate(obj.to_f)
      else
        JSON.generate(obj)
      end
    end
    
    # Returns the document content as a literal Javascript object. If a callback was specified,
    # the object is wrapped in a Javascript function call.
    def to_s
      j = __serialize(@content)
      @callback ? "#{@callback}(#{j});" : j
    end
    
    alias_method :to_json, :to_s
    alias_method :inspect, :to_s
  end
end
