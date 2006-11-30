module ServerSide
  class Dataset
    include Enumerable
  
    def initialize(db, opts = {})
      @db = db
      @opts = opts || {}
    end
    
    def dup_merge(opts)
      self.class.new(@db, @opts.merge(opts))
    end
    
    AS_REGEXP = /(.*)___(.*)/.freeze
    AS_FORMAT = "%s AS %s".freeze
    DOUBLE_UNDERSCORE = '__'.freeze
    PERIOD = '.'.freeze
    
    # sql helpers
    def field_name(field)
      s = field.to_s
      if field.is_a?(Symbol)
        if s =~ AS_REGEXP
          s = AS_FORMAT % [$1, $2]
        end
        s.split(DOUBLE_UNDERSCORE).join(PERIOD)
      else
        s
      end
    end
    
    WILDCARD = '*'.freeze
    COMMA_SEPARATOR = ", ".freeze
    
    def field_list(fields)
      case fields
      when Array:
        if fields.empty?
          WILDCARD
        else
          fields.map {|i| field_name(i)}.join(COMMA_SEPARATOR)
        end
      else
        fields
      end
    end
    
    def source_list(source)
      case source
      when Array: source.join(COMMA_SEPARATOR)
      else source
      end 
    end
    
    # DSL constructors
    def from(source)
      dup_merge(:from => source)
    end
    
    def select(*fields)
      fields = fields.first if fields.size == 1
      dup_merge(:select => fields)
    end
    
    def from!(source)
      @sql = nil
      @opts[:from] = source
      self
    end
    
    def select!(*fields)
      @sql = nil
      fields = fields.first if fields.size == 1
      @opts[:select] = fields
      self
    end
  end
end
