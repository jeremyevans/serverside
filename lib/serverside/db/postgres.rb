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
    SELECT = "SELECT %s FROM %s".freeze
    LIMIT = "LIMIT %s".freeze
  
    def each(field = nil, &block)
      @db.synchronize do
        execute
        @result.each do |r|
          row = fetch_row(r)
          block.call(field ? row[field] : row)
        end
      end
      self
    end
    
    def all(field = nil)
      result = []
      @db.synchronize do
        execute
        @result.each do |r|
          row = fetch_row(r)
          result << (field ? row[field] : row)
        end
      end
      result
    end
    
    def first
      @db.synchronize do
        execute(@opts.merge(:limit => 1))
        @result.each do |r|
          break fetch_row(r)
        end
      end
    end
    
    def execute(opts = nil)
      @result = @db.conn.exec(compile_sql(opts))
      @fields = @result.fields.map {|s| s.to_sym}
      @types = (0..(@result.num_fields - 1)).map {|idx| @result.type(idx)}
      compile_row_fetcher
    end

    def compile_sql(opts = nil)
      custom_opts = !opts.nil?
      return @sql if @sql && custom_opts

      opts = @opts if opts.nil?
      fields = opts[:select]
      select_fields = fields ? field_list(fields) : "*"
      select_source = source_list(opts[:from]) 
      select_clause = SELECT % [select_fields, select_source]
      
      limit = opts[:limit]
      limit_clause = limit ? LIMIT % [limit] : ''
      
      sql = [select_clause, limit_clause].join(' ')
      @sql = sql unless custom_opts
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
