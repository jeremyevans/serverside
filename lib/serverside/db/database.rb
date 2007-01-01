require 'thread'

require File.join(File.dirname(__FILE__), 'schema')

module ServerSide
  class Database
    def initialize(opts = {})
      @opts = opts
    end

    # Some convenience methods
    
    # Returns a new dataset with the from method invoked.
    def from(*args); query.from(*args); end
    
    # Returns a new dataset with the select method invoked.
    def select(*args); query.select(*args); end

    # returns a new dataset with the from method invoked. For example,
    #
    #   db[:posts].each {|p| puts p[:title]}
    def [](table)
      query.from(table)
    end

    def literal(v)
      case v
      when String: "'%s'" % v
      else v.to_s
      end
    end
    
    def create_table(name, columns, indexes = nil)
      execute Schema.create_table_sql(name, columns, indexes)
    end
    
    def drop_table(name)
      execute Schema.drop_table_sql(name)
    end
    
    def table_exists?(name)
      from(name).count
      true
    rescue
      false
    end
  end
end

class Time
  SQL_FORMAT = "TIMESTAMP '%Y-%m-%d %H:%M:%S'".freeze
    
  def to_sql_timestamp
    strftime(SQL_FORMAT)  
  end
end
