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
      when Symbol:
        field_name(fields)
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

    def order(*order)
      dup_merge(:order => order)
    end
    
    DESC_ORDER_REGEXP = /(.*)\sDESC/.freeze
    
    def reverse_order(order)
      order.map do |f|
        if f.to_s =~ DESC_ORDER_REGEXP
          $1
        else
          f.DESC
        end
      end
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

    alias_method :all, :to_a
    
    alias_method :enum_map, :map
    
    def map(*args, &block)
      if block
        enum_map(&block)
      else
        enum_map do |r|
          args.map {|f| r[f]}
        end
      end
    end
  end
end

class Symbol
  def DESC
    "#{to_s} DESC"
  end
  
  AS_REGEXP = /(.*)___(.*)/.freeze
  AS_FORMAT = "%s AS %s".freeze
  DOUBLE_UNDERSCORE = '__'.freeze
  PERIOD = '.'.freeze
  
  def field_name
    s = to_s
    if s =~ AS_REGEXP
      s = AS_FORMAT % [$1, $2]
    end
    s.split(DOUBLE_UNDERSCORE).join(PERIOD)
  end
  
  def AS(target)
    "#{field_name} AS #{target}"
  end  

end

