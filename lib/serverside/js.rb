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
      end
      @stack.last.__add_hash_value(key, value)
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
    def __serialize(obj, quote_keys)
      case obj
      when Time: JSON.generate(obj.to_f)
      else
        JSON.generate(obj)
      end
    end
    
    # Returns the document content as a literal Javascript object. If a callback was specified,
    # the object is wrapped in a Javascript function call.
    def to_s
      j = __serialize(@content, false)
      @callback ? "#{@callback}(#{j});" : j
    end
    
    # Returns the content in JSON format.
    def to_json
      __serialize(@content, true)
    end
    
    alias_method :inspect, :to_s
  end
end

__END__

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
      end
      @stack.last.__add_hash_value(key, value)
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
      value = value.__content if value.respond_to?(:__js)
      @stack.last.__add_array_value(value)
    end
    
    # Returns the current document content.
    def __content
      @content
    end
    
    NULL = 'null'.freeze
    
    # Serializes the specified object into JS/JSON format. 
    def __serialize(obj, quote_keys)
      if obj.nil?
        NULL
      elsif obj.is_a? Array
        "[#{obj.map{|v| __serialize(v, quote_keys)}.join(', ')}]"
      elsif obj.is_a? Hash
        if quote_keys
          fields = obj.to_a.map{|kv| "\"#{kv[0]}\": #{__serialize(kv[1], quote_keys)}"}
        else
          fields = obj.to_a.map{|kv| "#{kv[0]}: #{__serialize(kv[1], quote_keys)}"}
        end
        "{#{fields.join(', ')}}"
      elsif obj.is_a? Symbol
        obj.to_s
      elsif obj.is_a? Time
        obj.to_f
      else
        obj.inspect
      end
    end
    
    # Returns the document content as a literal Javascript object. If a callback was specified,
    # the object is wrapped in a Javascript function call.
    def to_s
      j = __serialize(@content, false)
      @callback ? "#{@callback}(#{j});" : j
    end
    
    # Returns the content in JSON format.
    def to_json
      __serialize(@content, true)
    end
    
    alias_method :inspect, :to_s
  end
end
