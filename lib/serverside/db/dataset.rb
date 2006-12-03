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
      field.is_a?(Symbol) ? field.to_field_name : field
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
        fields.to_field_name
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
    
    AND_SEPARATOR = " AND ".freeze
    EQUAL_COND = "(%s = %s)".freeze
    
    def literal(v)
      case v
      when String 
      else v.to_s
      end
    end
    
    def where_list(where)
      case where
      when Hash: where.map {|kv| EQUAL_COND % kv}.join(AND_SEPARATOR)
      when Array:
        fmt = where.shift
        fmt.gsub('?') {|i| literal(where.shift)}
      else
        where
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
    
    def where(*where)
      where = where.first if where.size == 1
      dup_merge(:where => where)
    end

    alias_method :filter, :where

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

    SELECT = "SELECT %s FROM %s".freeze
    LIMIT = "LIMIT %s".freeze
    ORDER = "ORDER BY %s".freeze
    WHERE = "WHERE %s".freeze
  
    def select_sql(opts = nil)
      opts = @opts if opts.nil?
      fields = opts[:select]
      select_fields = fields ? field_list(fields) : "*"
      select_source = source_list(opts[:from]) 
      select_clause = SELECT % [select_fields, select_source]
      
      order = opts[:order]
      order_clause = order ? ORDER % order.join(', ') : ''
      
      where = opts[:where]
      where_clause = where ? WHERE % where_list(where) : ''
      
      limit = opts[:limit]
      limit_clause = limit ? LIMIT % limit : ''
      
      [select_clause, order_clause, where_clause, limit_clause].join(' ')
    end
    
    def count_sql(opts = nil)
      opts = @opts if opts.nil?
      fields = opts[:select]
      select_fields = "COUNT(*)"
      select_source = source_list(opts[:from]) 
      select_clause = SELECT % [select_fields, select_source]
      
      order = opts[:order]
      order_clause = order ? ORDER % order.join(', ') : ''
      
      where = opts[:where]
      where_clause = where ? WHERE % where_list(where) : ''
      
      limit = opts[:limit]
      limit_clause = limit ? LIMIT % limit : ''
      
      [select_clause, order_clause, where_clause, limit_clause].join(' ')
    end
  end
end

class Symbol
  def DESC
    "#{to_s} DESC"
  end
  
  def AS(target)
    "#{field_name} AS #{target}"
  end  

  AS_REGEXP = /(.*)___(.*)/.freeze
  AS_FORMAT = "%s AS %s".freeze
  DOUBLE_UNDERSCORE = '__'.freeze
  PERIOD = '.'.freeze
  
  def to_field_name
    s = to_s
    if s =~ AS_REGEXP
      s = AS_FORMAT % [$1, $2]
    end
    s.split(DOUBLE_UNDERSCORE).join(PERIOD)
  end
end

