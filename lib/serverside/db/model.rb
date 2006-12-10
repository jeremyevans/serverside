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
    
    def self.dataset
      @dataset ||= database[table_name]
    end
    def self.set_dataset(ds); @dataset = ds; end
  end
end

ServerSide::Model.database = Postgres::Database.new

class Node < ServerSide::Model
  set_table_name :nodes
end
