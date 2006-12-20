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
      puts "****************************************"
      puts sql
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
    
    LIKE = '%s ~ %s'.freeze
    LIKE_CI = '%s ~* %s'.freeze
    
    def where_equal_condition(left, right)
      if right.is_a?(Regexp)
        (right.casefold? ? LIKE_CI : LIKE) %
          [field_name(left), PGconn.quote(right.source)]
      else
        super
      end
#      EQUAL_COND % [field_name(left), literal(right)]
    end
    
    def each(opts = nil, &block)
      @db.synchronize do
        perform select_sql(opts), true
        result_each(&block)
      end
      self
    end
    
    LIMIT_1 = {:limit => 1}.freeze
    
    def first(opts = nil)
      opts = opts ? opts.merge(LIMIT_1) : LIMIT_1
      @db.synchronize do
        perform select_sql(opts), true
        result_first
      end
    end
    
    def last(opts = nil)
      raise RuntimeError, 'No order specified' unless
        @opts[:order] || (opts && opts[:order])
      
      opts = {:order => reverse_order(@opts[:order])}.
        merge(opts ? opts.merge(LIMIT_1) : LIMIT_1)
      
      @db.synchronize do
        perform select_sql(opts), true
        result_first
      end
    end
    
    FOR_UPDATE = ' FOR UPDATE'.freeze
    FOR_SHARE = ' FOR SHARE'.freeze
    
    def select_sql(opts = nil)
      row_lock_mode = opts ? opts[:lock] : @opts[:lock]
      sql = super
      case row_lock_mode
      when :update : sql << FOR_UPDATE.freeze
      when :share  : sql << FOR_SHARE.freeze
      end
      sql
    end
    
    def for_update
      dup_merge(:lock => :update)
    end
    
    def for_share
      dup_merge(:lock => :share)
    end
    
    EXPLAIN = 'EXPLAIN '.freeze
    QUERY_PLAN = 'QUERY PLAN'.to_sym
    
    def explain(opts = nil)
      db.synchronize {perform EXPLAIN + select_sql(opts)}
      result = []
      result_each {|r| result << r[QUERY_PLAN]}
      result.join("\r\n")
    end
    
    LOCK = 'LOCK TABLE %s IN %s MODE;'.freeze
    
    ACCESS_SHARE = 'ACCESS SHARE'.freeze
    ROW_SHARE = 'ROW SHARE'.freeze
    ROW_EXCLUSIVE = 'ROW EXCLUSIVE'.freeze
    SHARE_UPDATE_EXCLUSIVE = 'SHARE UPDATE EXCLUSIVE'.freeze
    SHARE = 'SHARE'.freeze
    SHARE_ROW_EXCLUSIVE = 'SHARE ROW EXCLUSIVE'.freeze
    EXCLUSIVE = 'EXCLUSIVE'.freeze
    ACCESS_EXCLUSIVE = 'ACCESS EXCLUSIVE'.freeze
    
    # Locks the table with the specified mode.
    def lock(mode, &block)
      sql = LOCK % [@opts[:from], mode]
      db.synchronize do
        if block # perform locking inside a transaction and yield to block
          db.transaction {perform sql; yield}
        else
          perform sql # lock without a transaction
          self
        end
      end
    end
  
    def count(opts = nil)
      db.synchronize {perform count_sql(opts); result_first[:count]}
    end
    
    SELECT_LASTVAL = ';SELECT lastval()'.freeze
    
    def insert(values, opts = nil)
      db.synchronize do
        perform insert_sql(values, opts) + SELECT_LASTVAL
        result_first[:lastval]
      end
    end
    
    def update(values, opts = nil)
      db.synchronize do
        perform update_sql(values, opts)
        @result.cmdtuples
      end
    end
    
    def delete(opts = nil)
      db.synchronize do
        perform delete_sql(opts)
        @result.cmdtuples
      end
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
    FETCH_FIELD = "%s => r[%s]%s".freeze
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
        m << (FETCH_FIELD % [field.inspect, f, translator])
      end
      s = (use_record_class && @record_class) ?
        (FETCH_RECORD_CLASS % [@record_class, parts.join(',')]) : 
        (FETCH % parts.join(','))
      l = eval(s)
      meta_def(:fetch_row, &l)
    end
  end
end
