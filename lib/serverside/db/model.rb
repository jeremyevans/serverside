#require 'rubygems'
require 'metaid'

module ServerSide
  class Model
    @@database = nil
    def self.database; @@database; end
    def self.database=(db); @@database = db; end
    
    def self.table_name; @table_name; end
    def self.set_table_name(t); @table_name = t; end

    def self.dataset
      return @dataset if @dataset
      if !table_name
        raise RuntimeError, "Table name not specified for class #{self}."
      elsif !database
        raise RuntimeError, "No database connected."
      end
      @dataset = database[table_name]
      @dataset.record_class = self
      @dataset
    end
    def self.set_dataset(ds); @dataset = ds; @dataset.record_class = self; end
    
    def self.primary_key; @primary_key ||= :id; end
    def self.set_primary_key(k); @primary_key = k; end
    
    def self.schema(name = nil, &block)
      name ||= table_name
      @schema = Schema::Generator.new(name, &block)
      set_table_name name
      if @schema.primary_key_name
        set_primary_key @schema.primary_key_name
      end
    end
    
    def self.table_exists?
      dataset.count
      true
    rescue
      false
    end
    
    def self.create_table
      database.execute get_schema.to_s
    end
    
    def self.drop_table
      database.execute Schema.drop_table_sql(table_name)
    end
    
    def self.get_schema
      @schema
    end
    
    ONE_TO_ONE_PROC = "proc {i = @values[:%s]; %s[i] if i}".freeze
    ID_POSTFIX = "_id".freeze
    
    def self.one_to_one(name, opts)
      klass = opts[:class] || self
      key = opts[:key] || (name.to_s + ID_POSTFIX)
      define_method name, &eval(ONE_TO_ONE_PROC % [key, klass])
    end
  
    ONE_TO_MANY_PROC = "proc {%s.filter(:%s => @values[:%s])}".freeze  
    def self.one_to_many(name, opts)
      klass = opts[:class] || self
      keys = opts[:key].to_a.first
      define_method name, &eval(ONE_TO_MANY_PROC % [klass, keys[0], keys[1]])
    end

    ############################################################################
    
    attr_reader :values, :pkey
    
    def primary_key
      self.class.primary_key
    end
    
    def initialize(values)
      @values = values
      @pkey = values[primary_key]
    end
    
    def self.find(cond)
      dataset.filter(cond).first# || (raise RuntimeError, "Record not found.")
    end
    
    def self.all; dataset.all; end
    def self.filter(cond); dataset.filter(cond); end
    def self.first; dataset.first; end
    def self.count; dataset.count; end
    def self.join(*args); dataset.join(*args); end
    def self.delete(*args); dataset.delete(*args); end
    
    def self.[](key)
      find key.is_a?(Hash) ? key : {primary_key => key}
    end
    
    def self.create(values)
      find primary_key => dataset.insert(values)
    end
    
    BY_REGEXP = /by_(.*)/.freeze
    
    def self.method_missing(m, *args)
      method_name = m.to_s
      if method_name =~ BY_REGEXP
        meta_def(method_name) {|arg| find($1 => arg)}
        send(m, *args) if respond_to?(m)
      else
        super
      end
    end
    
    def [](field); @values[field]; end
    
    def set(values)
      dataset.filter(primary_key => @pkey).update(values)
      @values.merge!(values)
    end
  end
  
  def self.Model(table_name)
    Class.new(ServerSide::Model) do
      meta_def(:inherited) {|c| c.set_table_name(table_name)}
    end
  end
end

__END__

class Node < ServerSide::Model(:nodes)
end

class NodeAttribute < ServerSide::Model(:node_attributes)
end




ServerSide::Model.database = Postgres::Database.new

class Node < ServerSide::Model
  schema :nodes do
    
  end

  one_to_one :parent, :class => Node, :key => :parent_id
  one_to_many :children, :class => Node, :key => {:parent_id => :id}
end

$atts = ServerSide::Model.database[:node_attributes] 

#Node.dataset.filter(:path => '/sas').delete

 
