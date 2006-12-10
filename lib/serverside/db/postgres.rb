require 'postgres'
require 'metaid'
require 'mutex_m'

require File.join(File.dirname(__FILE__), 'database')
require File.join(File.dirname(__FILE__), 'dataset')

module Postgres
  PG_TYPES = {
    16 => :to_bool,
    20 => :to_i,
    21 => :to_i,
    22 => :to_i,
    23 => :to_i,
    700 => :to_f,
    701 => :to_f
  }

  class Database < ServerSide::Database
    include Mutex_m
    
    def make_connection
      PGconn.connect(
        @opts[:host] || 'localhost',
        @opts[:port] || 5432,
        '', '',
        @opts[:database] || 'reality_development',
        @opts[:user] || 'postgres',
        @opts[:password] || '240374'
      )
    end
    
    def query(opts = nil)
      Postgres::Dataset.new(self, opts)
    end
    
    def execute(sql)
      @conn.exec(sql)
    end
    
    SQL_BEGIN = 'BEGIN'.freeze
    SQL_COMMIT = 'COMMIT'.freeze
    SQL_ROLLBACK = 'ROLLBACK'.freeze
    
    def transaction
      execute(SQL_BEGIN)
      yield
      execute(SQL_COMMIT)
    rescue => e
      execute(SQL_ROLLBACK)
      raise e
    end
  end
  
  class Dataset < ServerSide::Dataset
    attr_reader :result
  
    def each(opts = nil, &block)
      @db.synchronize do
        select(opts)
        result_each(&block)
      end
      self
    end
    
    def first
      raise RuntimeError, 'No order specified' unless @opts[:order]
      @db.synchronize do
        select(@opts.merge(:limit => 1))
        result_first
      end
    end
    
    def last
      raise RuntimeError, 'No order specified' unless @opts[:order]
      @db.synchronize do
        select(@opts.merge(
          :limit => 1, :order => reverse_order(@opts[:order])))
        result_first
      end
    end
    
    def select(opts = nil)
      perform select_sql(opts)
    end

    def count(opts = nil)
      perform count_sql(opts)
      result_first[:count]
    end
    
    
    SELECT_LASTVAL = ';SELECT lastval()'.freeze
    
    def insert(values, opts = nil)
      perform insert_sql(values, opts) + SELECT_LASTVAL
      result_first[:lastval]
      #last_insert_id
    end
    
    def delete(opts = nil)
      perform delete_sql(opts)
      @result.cmdtuples
    end
    
    def perform(sql)
      @result = @db.execute(sql)
      @fields = @result.fields.map {|s| s.to_sym}
      @types = (0..(@result.num_fields - 1)).map {|idx| @result.type(idx)}
      compile_row_fetcher
      @result
    end
    
    def result_each
      @result.each {|r| yield fetch_row(r)}
    end
    
    def result_first
      @result.each {|r| return fetch_row(r)}
    end

    def compile_row_fetcher
      parts = (0..(@result.num_fields - 1)).inject([]) do |m, f|
        translate_fn = PG_TYPES[@types[f]]
        translator = translate_fn ? ".#{translate_fn}" : ""
        m << ":#{@fields[f]} => r[#{f}]#{translator}"
      end
      l = eval("lambda {|r|{#{parts.join(',')}}}")
      meta_def(:fetch_row, &l)
    end
  end
end

DB = Postgres::Database.new
$d = DB[:nodes]
$e = DB[:node_attributes]

__END__

$e.delete

x = 1000

t1 = Time.now
x.times do
  $e.insert(:node_id => rand(10_000), :kind => rand(10_000), 
    :value => rand(100_000_000))
end
t2 = Time.now
e = t2 - t1
r = x/e
puts "Inserted #{x} records in #{e} seconds (#{r} recs/s)"

t1 = Time.now
x = 10
x.times { $e.each {|r| r} }
t2 = Time.now
e = t2 - t1
r = x/e
puts "Performed select query #{x} times in #{e} seconds (#{r} query/s)"

