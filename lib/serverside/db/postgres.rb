require 'postgres'
require 'metaid'
require 'mutex_m'

class PGconn
  # the pure-ruby postgres adapter does not have a quote method.
  unless methods.include?('quote')
    def self.quote(obj)
      case obj
      when true: 't'
      when false: 'f'
      when nil: 'NULL'
      when String: "'#{obj}'"
      else obj.to_s
      end
    end
  end
  
  def connected?
    status == PGconn::CONNECTION_OK
  end
end

require File.join(File.dirname(__FILE__), 'database')
require File.join(File.dirname(__FILE__), 'dataset')

class String
  def postgres_to_bool
    if self == 't'
      true
    elsif self == 'f'
      false
    else
      nil
    end
  end
  
  def postgres_to_time
    Time.parse(self)
  end
end

module Postgres
  PG_TYPES = {
    16 => :postgres_to_bool,
    20 => :to_i,
    21 => :to_i,
    22 => :to_i,
    23 => :to_i,
    700 => :to_f,
    701 => :to_f,
    1114 => :postgres_to_time
  }

  class Database < ServerSide::Database
    attr_reader :pool
    
    def initialize(opts = {})
      super
      @pool = ServerSide::ConnectionPool.new(@opts[:max_connections] || 4) do
        PGconn.connect(
          @opts[:host] || 'localhost',
          @opts[:port] || 5432,
          '', '',
          @opts[:database] || 'reality_development',
          @opts[:user] || 'postgres',
          @opts[:password])
      end
    end
    
    
    def query(opts = nil)
      Postgres::Dataset.new(self, opts)
    end
    
    RELATION_QUERY = {:from => :pg_class, :select => :relname}.freeze
    RELATION_FILTER = "(relkind = 'r') AND (relname !~ '^pg|sql')".freeze
    SYSTEM_TABLE_REGEXP = /^pg|sql/.freeze
    
    
    def tables
      query(RELATION_QUERY).filter(RELATION_FILTER).map(:relname)
    end
    
    def execute(sql)
#      puts "****************************************"
#      puts sql
      @pool.hold_connection do |conn|
        begin
          conn.exec(sql)
        rescue PGError => e
          unless conn.connected?
            conn.reset
            conn.exec(sql)
          else
            p sql
            p e
#            puts e.backtrace.join("\r\n")
            raise e
          end
        end
      end
    end
    
    def synchronize(&block)
      @pool.hold_connection(&block)
    end
    
    SQL_BEGIN = 'BEGIN'.freeze
    SQL_COMMIT = 'COMMIT'.freeze
    SQL_ROLLBACK = 'ROLLBACK'.freeze
    
    def transaction
      if @transaction_in_progress
        return yield
      end
      @transaction_in_progress = true
      execute(SQL_BEGIN)
      result = yield
      execute(SQL_COMMIT)
      @transaction_in_progress = nil
      result
    rescue => e
      execute(SQL_ROLLBACK)
      raise e
    end

    def table_exists?(name)
      from(:pg_class).filter(:relname => name, :relkind => 'r').count > 0
    end
  end
  
  class Dataset < ServerSide::Dataset
    attr_reader :result, :fields
  
    def literal(v)
      case v
      when Time: v.to_sql_timestamp
      when Symbol: PGconn.quote(v.to_s)
      when Array: v.empty? ? EMPTY_ARRAY : v.join(COMMA_SEPARATOR)
      else
        PGconn.quote(v)
      end
    end
    
    LIKE = '%s ~ %s'.freeze
    LIKE_CI = '%s ~* %s'.freeze
    
    IN_ARRAY = '%s IN (%s)'.freeze
    EMPTY_ARRAY = 'NULL'.freeze
    
    def where_equal_condition(left, right)
      case right
      when Regexp:
        (right.casefold? ? LIKE_CI : LIKE) %
          [field_name(left), PGconn.quote(right.source)]
      when Array:
        IN_ARRAY % [field_name(left), literal(right)]
      else
        super
      end
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
    def lock(mode)
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
    
    def insert(values = nil, opts = nil)
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
      prepare_row_fetcher(use_record_class)
      @result
    end
    
    def result_each
      @result.each {|r| yield fetch_row(r)}
    end
    
    def result_first
      @result.each {|r| return fetch_row(r)}
      nil
    end
    
    COMMA = ','.freeze
    
    def prepare_row_fetcher(use_record_class)
      @fields = @result.fields.map {|s| s.to_sym}
      @types = (0..(@result.num_fields - 1)).map {|idx| @result.type(idx)}
      @result_class = use_record_class ? @record_class : nil
      signature = @fields.join(COMMA) + @types.join(COMMA) + @result_class.to_s
      meta_def(:fetch_row, &fetcher_by_signature(signature))
    end
    
    @@signatures_mutex = Mutex.new
    @@signatures = {}

    def fetcher_by_signature(signature)
      @@signatures_mutex.synchronize do
        @@signatures[signature] ||= compile_row_fetcher
      end
    end
    
    FETCH = "lambda {|r| {%s}}".freeze
    FETCH_RECORD_CLASS = "lambda {|r| %2$s.new(%1$s)}".freeze
    
    FETCH_FIELD = '%s => r[%d]'.freeze
    FETCH_FIELD_TRANSLATE = '%s => ((t = r[%d]) ? t.%s : nil)'.freeze

    def compile_row_fetcher
      used_fields = []
      kvs = []
      @fields.each_with_index do |field, idx|
        next if used_fields.include?(field)
        used_fields << field
        
        translate_fn = PG_TYPES[@types[idx]]
        kvs << (translate_fn ? FETCH_FIELD_TRANSLATE : FETCH_FIELD) %
          [field.inspect, idx, translate_fn]
      end
      s = (@result_class ? FETCH_RECORD_CLASS : FETCH) %
        [kvs.join(COMMA), @result_class]
      eval(s)
    end
  end
end

