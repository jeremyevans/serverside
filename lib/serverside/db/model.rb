module ServerSide
  class Model
    @@database = nil
    def self.database; @@database; end
    def self.database=(db); @@database = db; end
    
    def self.table_name
      @table_name || (raise RuntimeError, 
        "Table name not specified for class #{self.class}.")
    end
    def self.set_table_name(t); @table_name = t; end

    def self.table(t)
      Class.new(self) do
        meta_def(:inherited) {|c| c.set_table_name(t)}
      end
    end
    
    def self.dataset
      @dataset ||= database[table_name]
    end
    def self.set_dataset(ds); @dataset = ds; end
    
    def self.primary_key; @primary_key ||= :id; end
    def self.set_primary_key(k); @primary_key = k; end
    
    ############################################################################
    
    attr_reader :values, :pkey
    
    def initialize(values)
      @values = values
      @pkey = values[self.class.primary_key]
    end
    
    def self.find(cond)
      dataset.filter(cond).first || (raise RuntimeError, "Record not found.")
    end
    
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
        meta_def(method_name) do |arg|
          values = find($1 => arg)
          values ? new(values) : nil
        end
        send(m, *args) if respond_to?(m)
      else
        super
      end
    end
    
    def [](field); @values[field]; end
    
    def set(values)
      dataset.filter(primary_key => key).update(values)
      @values.merge!(values)
    end
  end
end

ServerSide::Model.database = Postgres::Database.new

class Node < ServerSide::Model.table(:nodes)
end

#Node.dataset.filter(:path => '/sas').delete

 
