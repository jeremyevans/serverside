require 'logger'

module ServerSide
  @@logger = nil
  
  def self.logger
    @@logger
  end
  
  def self.logger=(l)
    @@logger = l
  end
  
  def self.setup_stock_logger(logdev, shift_age = 0, shift_size = 1048576)
    @@logger = Logger.new(logdev, shift_age, shift_size)
    @@logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    @@logger
  end
  
  def self.logger_level=(level)
    @@logger.level = level if @@logger
  end

  def self.log(level, text)
    @@logger.log(level, text) if @@logger
  end
  
  def self.debug(text)
    @@logger.debug(text) if @@logger
  end
  
  def self.info(text)
    @@logger.info(text) if @@logger
  end
  
  def self.warn(text)
    @@logger.warn(text) if @@logger
  end
  
  def self.error(text)
    @@logger.error(text) if @@logger
  end
  
  def self.fatal(text)
    @@logger.fatal(text) if @@logger
  end
  
  def self.log_error(e)
    if @@logger
      @@logger.error("#{e.message}:\r\n" + e.backtrace.join("\r\n"))
    end
  end
  
  REFERER = "Referer".freeze
  USER_AGENT = "User-Agent".freeze
  HOST = "Host".freeze
  HOST_REGEXP = /([^\:]*)(\:(.*))?$/
  
  def self.log_request(r)
    if @@logger
      return unless req_line = r.req_line
      req_line.chomp!
      if r.method == :post && r.content_type == HTTP::Request::CONTENT_TYPE_URL_ENCODED
        req_line << " (#{r.body})"
      end
      host = (r.headers[HOST] || "") =~ HOST_REGEXP ? $1 : ""
      msg = "%s %s %s %s %s %s %s" % [
        r.client_addr,
        host.inspect,
        req_line.inspect,
        r.status || '?',
        r.content_length || '?',
        (r.headers[REFERER] || "").inspect,
        (r.headers[USER_AGENT] || "").inspect
      ]
      @@logger.info(msg)
    end
  end
end
