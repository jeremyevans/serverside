require 'metaid'

module ServerSide
  # Handles serialization of data into JSON format.
  class JSON
    # blank slate
    instance_methods.each { |m| 
      undef_method m unless (m =~ /^__|instance_eval|meta/)
    }
  
    # Initializes a new JSON document.
    def initialize(callback = nil, &block)
      @callback = callback
      @stack = [self]
      instance_eval(&block) if block
    end
    
    # Performs most of the work by adding new values.
    def method_missing(key, *args, &block)
      unless block.nil?
        @stack.push JSON.new
        block.call(self)
        child = @stack.pop
        @stack.last._add_value(child._content, (key == :_item) ? nil : key)
      else
        @stack.last._add_value(args.first, (key == :_item) ? nil : key)
      end
      self
    end
    
    # Returns the internal data structure in text format.
    def inspect
      @content.inspect.to_s
    end
    
    # Adds the value as hash or array item.
    def _add_value(value, key = nil)
      if key.nil?
        @content ||= []
        @content << value
      else
        @content ||= {}
        @content[key] = value
      end
    end
    
    # Returns the current document content.
    def _content
      @content
    end
    
    # Serializes the specified content in JSON format. 
    def _jsonize(obj)
      if obj.nil?
        "null"
      elsif obj.is_a? Array
        "[#{obj.map{|v| _jsonize(v)}.join(', ')}]"
      elsif obj.is_a? Hash
        fields = obj.to_a.map{|kv| "#{kv[0]}: #{_jsonize(kv[1])}"}
        "{#{fields.join(', ')}}"
      elsif obj.is_a? Symbol
        obj.to_s
      elsif obj.is_a? Time
        obj.to_f
      else
        obj.inspect
      end
    end
    
    # Returns the document content in JSON format.
    def to_s
      j = _jsonize(@content)
      @callback ? "#{@callback}(#{j})" : j
    end
  end
end
