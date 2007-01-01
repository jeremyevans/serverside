#require 'rubygems'
require 'metaid'

module ServerSide
  class Model
    @@db = nil
    
    def self.db; @@db; end
    def self.db=(db); @@db = db; end
    
    def self.table_name; @table_name; end
    def self.set_table_name(t); @table_name = t; end

    def self.dataset
      return @dataset if @dataset
      if !table_name
        raise RuntimeError, "Table name not specified for class #{self}."
      elsif !db
        raise RuntimeError, "No database connected."
      end
      @dataset = db[table_name]
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
      db.table_exists?(table_name)
    end
    
    def self.create_table
      db.execute get_schema.create_sql
    end
    
    def self.drop_table
      db.execute get_schema.drop_sql
    end
    
    def self.recreate_table
      drop_table if table_exists?
      create_table
    end
    
    def self.get_schema
      @schema
    end
    
    ONE_TO_ONE_PROC = "proc {i = @values[:%s]; %s[i] if i}".freeze
    ID_POSTFIX = "_id".freeze
    FROM_DATASET = "db[%s]".freeze
    
    def self.one_to_one(name, opts)
      klass = opts[:class] ? opts[:class] : (FROM_DATASET % name.inspect)
      key = opts[:key] || (name.to_s + ID_POSTFIX)
      define_method name, &eval(ONE_TO_ONE_PROC % [key, klass])
    end
  
    ONE_TO_MANY_PROC = "proc {%s.filter(:%s => @pkey)}".freeze
    ONE_TO_MANY_ORDER_PROC = "proc {%s.filter(:%s => @pkey).order(%s)}".freeze
    def self.one_to_many(name, opts)
      klass = opts[:class] ? opts[:class] :
        (FROM_DATASET % (opts[:table] || name.inspect))
      key = opts[:on]
      order = opts[:order]
      define_method name, &eval(
        (order ? ONE_TO_MANY_ORDER_PROC : ONE_TO_MANY_PROC) %
        [klass, key, order.inspect]
      )
    end
    
    def self.get_hooks(key)
      @hooks ||= {}
      @hooks[key] ||= []
    end
    
    def self.has_hooks?(key)
      !get_hooks(key).empty?
    end
    
    def run_hooks(key)
      self.class.get_hooks(key).each {|h| instance_eval(&h)}
    end

    def self.before_delete(&block)
      get_hooks(:before_delete).unshift(block)
    end
    
    def self.after_create(&block)
      get_hooks(:after_create) << block
    end
    
    ############################################################################
    
    attr_reader :values, :pkey
    
    def model
      self.class
    end
    
    def primary_key
      model.primary_key
    end
    
    def initialize(values)
      @values = values
      @pkey = values[primary_key]
    end
    
    def exists?
      model.filter(primary_key => @pkey).count == 1
    end
    
    def refresh
      record = self.class.find(primary_key => @pkey)
      record ? (@values = record.values) : 
        (raise RuntimeError, "Record not found")
      self
    end
    
    def self.find(cond)
      dataset.filter(cond).first # || (raise RuntimeError, "Record not found.")
    end
    
    def self.all; dataset.all; end
    def self.filter(cond); dataset.filter(cond); end
    def self.first; dataset.first; end
    def self.count; dataset.count; end
    def self.join(*args); dataset.join(*args); end
    def self.lock(mode, &block); dataset.lock(mode, &block); end
    def self.delete_all
      if has_hooks?(:before_delete)
        db.transaction {dataset.all.each {|r| r.delete}}
      else
        dataset.delete
      end
    end
    
    def self.[](key)
      find key.is_a?(Hash) ? key : {primary_key => key}
    end
    
    def self.create(values = nil)
      obj = find(primary_key => dataset.insert(values))
      obj.run_hooks(:after_create)
      obj
    end
    
    def delete
      db.transaction do
        run_hooks(:before_delete)
        model.dataset.filter(primary_key => @pkey).delete
      end
    end
    
    FIND_BY_REGEXP = /^find_by_(.*)/.freeze
    FILTER_BY_REGEXP = /^filter_by_(.*)/.freeze
    
    def self.method_missing(m, *args)
      method_name = m.to_s
      if method_name =~ FIND_BY_REGEXP
        meta_def(method_name) {|arg| find($1 => arg)}
        send(m, *args) if respond_to?(m)
      elsif method_name =~ FILTER_BY_REGEXP
        meta_def(method_name) {|arg| filter($1 => arg)}
        send(m, *args) if respond_to?(m)
      else
        super
      end
    end
    
    def db; @@db; end
    
    def [](field); @values[field]; end
    
    def set(values)
      model.dataset.filter(primary_key => @pkey).update(values)
      @values.merge!(values)
    end
  end
  
  def self.Model(table_name)
    Class.new(ServerSide::Model) do
      meta_def(:inherited) {|c| c.set_table_name(table_name)}
    end
  end
end
