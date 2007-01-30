require 'metaid'

module ServerSide
  # Handles serialization of data into JSON format.
  class JS
    # blank slate
    instance_methods.each { |m| 
      undef_method m unless (m =~ /^__|instance_eval|meta|respond_to/)}
  
    # Initializes a new JSON document.
    def initialize(callback = nil, &block)
      @callback = callback
      @stack = [self]
      block.call(self) if block
    end
    
    def __js
      true
    end
    
    # Performs most of the work by adding new values.
    def method_missing(key, *args, &block)
      meta_def(key) do |*args|
        value = nil
        if block
          @stack.push JS.new
          block.call(self)
          value = @stack.pop.__content
        else
          value = args.first
          value = value.__content if value.respond_to?(:__js)
        end
        @stack.last.__add_hash_value(key, value)
        self
      end
      __send__(key, *args)
    end
    
    # Returns the internal data structure in text format.
    def inspect
      @content.inspect.to_s
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
      value = value.__content if value.respond_to?(:__js)
      @stack.last.__add_array_value(value)
    end
    
    # Returns the current document content.
    def __content
      @content
    end
    
    # Serializes the specified content in JSON format. 
    def __jsonize(obj)
      if obj.nil?
        "null"
      elsif obj.is_a? Array
        "[#{obj.map{|v| __jsonize(v)}.join(', ')}]"
      elsif obj.is_a? Hash
        fields = obj.to_a.map{|kv| "#{kv[0]}: #{__jsonize(kv[1])}"}
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
      j = __jsonize(@content)
      @callback ? "#{@callback}(#{j})" : j
    end
  end
end
