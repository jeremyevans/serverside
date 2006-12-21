require 'rubygems'
require 'postgres'

module ServerSide
  module Schema
    COMMA_SEPARATOR = ', '.freeze
    COLUMN_DEF = '%s %s'.freeze
    UNIQUE = ' UNIQUE'.freeze
    NOT_NULL = ' NOT NULL'.freeze
    DEFAULT = ' DEFAULT %s'.freeze
    
    TYPES = Hash.new {|h, k| k}
    TYPES[:double] = 'double precision'
    
    def column_definition(column)
      c = COLUMN_DEF % [column[:name], TYPES[column[:type]]]
      c << UNIQUE if column[:unique]
      c << NOT_NULL if column[:null] == false
      c << DEFAULT % PGconn.quote(column[:default]) if column[:default]
      c
    end
  
    def create_table_column_list(columns)
      columns.map {|c| column_definition(c)}.join(COMMA_SEPARATOR)
    end
    
    CREATE_INDEX = 'CREATE INDEX %s ON %s (%s);'.freeze
    CREATE_UNIQUE_INDEX = 'CREATE UNIQUE INDEX %s ON %s (%s);'.freeze
    INDEX_NAME = '%s_%s_index'.freeze
    UNDERSCORE = '_'.freeze
    
    def index_definition(table_name, index)
      fields = index[:columns].join(COMMA_SEPARATOR)
      index_name = index[:name] || INDEX_NAME %
        [table_name, index[:columns].join(UNDERSCORE)]
      (index[:unique] ? CREATE_UNIQUE_INDEX : CREATE_INDEX) %
        [index_name, table_name, fields]
    end
    
    def create_indexes_sql(table_name, indexes)
      indexes.map {|i| index_definition(table_name, i)}.join
    end
  
    CREATE_TABLE = "CREATE TABLE %s (%s);".freeze
    
    def create_table_sql(name, columns, indexes = nil)
      sql = CREATE_TABLE % [name, create_table_column_list(columns)]
      sql << create_indexes_sql(name, indexes) if indexes && !indexes.empty?
      sql
    end
    
    DROP_TABLE = "DROP TABLE %s;".freeze
    
    def drop_table_sql(name)
      DROP_TABLE % name
    end
    
    class Generator
      attr_reader :table_name
    
      def initialize(table_name, &block)
        @table_name = table_name
        @primary_key = {:name => :id, :type => :serial}
        @columns = []
        @indexes = []
        instance_eval(&block)
      end
      
      def primary_key(name, type = nil, opts = nil)
        @primary_key = {:name => name, :type => type || :serial}.merge(opts || {})
      end
      
      def primary_key_name
        @primary_key && @primary_key[:name]
      end
      
      def column(name, type, opts = nil)
        @columns << {:name => name, :type => type}.merge(opts || {})
      end
      
      def has_column?(name)
        @columns.each {|c| return true if c[:name] == name}
        false
      end
      
      def index(columns, opts = nil)
        columns = [columns] unless columns.is_a?(Array)
        @indexes << {:columns => columns}.merge(opts || {})
      end
      
      def to_s
        
        if @primary_key && !has_column?(@primary_key[:name])
          @columns.unshift(@primary_key)
        end
        create_table_sql(@table_name, @columns, @indexes)
      end
    end
  end
end

