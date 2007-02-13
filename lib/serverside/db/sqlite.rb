require 'sqlite3'
require 'metaid'

module ServerSide
  module SQLite
    class Database < ServerSide::Database
      attr_reader :pool
    
      def initialize(opts = {})
        super
        @pool = ServerSide::ConnectionPool.new(@opts[:max_connections] || 4) do
          db = SQLite3::Database.new(@opts[:database])
          db.type_translation = true
          db
        end
      end
    
      def query(opts = nil)
        SQLite::Dataset.new(self, opts)
      end
    
      def tables
        # return a list of tables
      end
    
      def execute(sql)
        @pool.hold {|conn| conn.execute(sql)}
      end
      
      def execute_insert(sql)
        @pool.hold {|conn| conn.execute(sql); conn.last_insert_row_id}
      end
      
      def single_value(sql)
        @pool.hold {|conn| conn.get_first_value(sql)}
      end
      
      def result_set(sql, record_class, &block)
        @pool.hold do |conn|
          conn.query(sql) do |result|
            columns = result.columns
            column_count = columns.size
            result.each do |values|
              row = {}
              column_count.times {|i| row[columns[i].to_sym] = values[i]}
              block.call(record_class ? record_class.new(row) : row)
            end
          end
        end
      end
      
      def synchronize(&block)
        @pool.hold(&block)
      end
    
      def transaction(&block)
        @pool.hold {|conn| conn.transaction(&block)}
      end

      def table_exists?(name)
      end
    end
    
    class Dataset < ServerSide::Dataset
      def each(opts = nil, &block)
        @db.result_set(select_sql(opts), @record_class, &block)
        self
      end
    
      LIMIT_1 = {:limit => 1}.freeze
    
      def first(opts = nil)
        opts = opts ? opts.merge(LIMIT_1) : LIMIT_1
        @db.result_set(select_sql(opts), @record_class) {|r| return r}
      end
    
      def last(opts = nil)
        raise RuntimeError, 'No order specified' unless
          @opts[:order] || (opts && opts[:order])
      
        opts = {:order => reverse_order(@opts[:order])}.
          merge(opts ? opts.merge(LIMIT_1) : LIMIT_1)
        @db.result_set(select_sql(opts), @record_class) {|r| return r}
      end
      
      def count(opts = nil)
        @db.single_value(count_sql(opts)).to_i
      end
    
      def insert(values = nil, opts = nil)
        @db.synchronize do
          @db.execute_insert insert_sql(values, opts)
        end
      end
    
      def update(values, opts = nil)
        @db.synchronize do
          @db.execute update_sql(values, opts)
        end
        self
      end
    
      def delete(opts = nil)
        @db.synchronize do
          @db.execute delete_sql(opts)
        end
        self
      end
    end
  end
end
