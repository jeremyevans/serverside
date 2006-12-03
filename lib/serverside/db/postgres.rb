require 'postgres'
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
  end
  
  class Dataset < ServerSide::Dataset
    def each(&block)
      @db.synchronize do
        select
        @result.each {|r| block.call(fetch_row(r))}
      end
      self
    end
    
    def first
      raise RuntimeError, 'No order specified' unless @opts[:order]
      @db.synchronize do
        select(@opts.merge(:limit => 1))
        @result.each do |r|
          break fetch_row(r)
        end
      end
    end
    
    def last
      raise RuntimeError, 'No order specified' unless @opts[:order]
      @db.synchronize do
        select(@opts.merge(
          :limit => 1, 
          :order => reverse_order(@opts[:order])
        ))
        @result.each do |r|
          break fetch_row(r)
        end
      end
    end
    
    def select(opts = nil)
      sql = select_sql(opts)
      puts "********************"
      puts sql
      @result = @db.conn.exec(sql)
      @fields = @result.fields.map {|s| s.to_sym}
      @types = (0..(@result.num_fields - 1)).map {|idx| @result.type(idx)}
      compile_row_fetcher
    end

    def count(opts = nil)
      sql = count_sql(opts)
      puts "********************"
      puts sql
      @result = @db.conn.exec(sql)
      @result.each {|r| return r.first.to_i}
    end

    def compile_row_fetcher
      parts = (0..(@result.num_fields - 1)).inject([]) do |m, f|
        translate_fn = PG_TYPES[@types[f]]
        translator = translate_fn ? ".#{translate_fn}" : ""
        m << ":#{@fields[f]} => r[#{f}]#{translator}"
      end
      l = eval("lambda {|r|{#{parts.join(',')}}}")
      extend(Module.new {define_method(:fetch_row, &l)})
    end
  end
end

DB = Postgres::Database.new
$d = DB[:nodes]
