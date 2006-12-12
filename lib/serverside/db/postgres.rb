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
        @opts[:password]
      )
    end
    
    def query(opts = nil)
      Postgres::Dataset.new(self, opts)
    end
    
    def connected?
      @conn.status == PGconn::CONNECTION_OK
    end
    
    def execute(sql)
      @conn.exec(sql)
    rescue PGError => e
      unless connected?
        @conn.reset
        @conn.exec(sql)
      else
        raise e
      end
    end
    
    SQL_BEGIN = 'BEGIN'.freeze
    SQL_COMMIT = 'COMMIT'.freeze
    SQL_ROLLBACK = 'ROLLBACK'.freeze
    
    def transaction
      execute(SQL_BEGIN)
      result = yield
      execute(SQL_COMMIT)
      result
    rescue => e
      execute(SQL_ROLLBACK)
      raise e
    end
  end
  
  class Dataset < ServerSide::Dataset
    attr_reader :result, :fields
  
    def literal(v)
      PGconn.quote(v)
    end
    
    def each(opts = nil, &block)
      @db.synchronize do
        select(opts)
        result_each(&block)
      end
      self
    end
    
    def first
#      raise RuntimeError, 'No order specified' unless @opts[:order]
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
      perform select_sql(opts), true
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
    
    def update(values, opts = nil)
      perform update_sql(values, opts)
      @result.cmdtuples
    end
    
    def delete(opts = nil)
      perform delete_sql(opts)
      @result.cmdtuples
    end
    
    def perform(sql, use_record_class = false)
      @result = @db.execute(sql)
      @fields = @result.fields.map {|s| s.to_sym}
      @types = (0..(@result.num_fields - 1)).map {|idx| @result.type(idx)}
      compile_row_fetcher(use_record_class)
      @result
    end
    
    def result_each
      @result.each {|r| yield fetch_row(r)}
    end
    
    def result_first
      @result.each {|r| return fetch_row(r)}
    end
    
    TRANSLATE = ".%s".freeze
    FETCH_FIELD = ":%s => r[%s]%s".freeze
    FETCH = "lambda {|r| {%s}}".freeze
    FETCH_RECORD_CLASS = "lambda {|r| %s.new(%s)}".freeze

    def compile_row_fetcher(use_record_class)
      used_fields = []
      parts = (0...@result.num_fields).inject([]) do |m, f|
        field = @fields[f]
        next m if used_fields.include?(field)
        
        used_fields << field
        translate_fn = PG_TYPES[@types[f]]
        translator = translate_fn ? (TRANSLATE % translate_fn) : EMPTY
        m << (FETCH_FIELD % [field, f, translator])
      end
      s = (use_record_class && @record_class) ?
        (FETCH_RECORD_CLASS % [@record_class, parts.join(',')]) : 
        (FETCH % parts.join(','))
      l = eval(s)
      meta_def(:fetch_row, &l)
    end
  end
end

__END__

DB = Postgres::Database.new
$d = DB[:nodes]
$e = DB[:node_attributes]

x = 10000

t1 = Time.now
x.times do
  $e.insert(:node_id => rand(1_000), :kind => rand(1_000), 
    :value => rand(100_000_000))
end
t2 = Time.now
e = t2 - t1
r = x/e
puts "Inserted #{x} records in #{e} seconds (#{r} recs/s)"

