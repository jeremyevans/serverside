module ServerSide::HTTP
  # HTTP Caching behavior
  module Caching
    # Sets caching-related headers (Cache-Control and Expires).
    def cache(opts)
      # check cache-control
      remove_cache_control
      if cache_control = opts[:cache_control]
        add_header(CACHE_CONTROL, cache_control)
      end
      
      # add an expires header
      if expires = opts[:expires] || (opts[:ttl] && (Time.now + opts[:ttl]))
        add_header(EXPIRES, expires.httpdate)
      end
    end
    
    # Validates the supplied request against specified validators (etag and
    # last-modified stamp). If a match is found, the status is changed to
    # 304 Not Modified. Otherwise, the supplied block is invoked.
    def validate_cache(opts, &block)
      valid_cache = false
      
      # check etag
      if etag = opts[:etag]
        etag = "\"#{etag}\""
        add_header(ETAG, etag) if etag
        valid_cache = etag_match(etag)
      end
      
      # check last_modified
      if last_modified = opts[:last_modified]
        add_header(LAST_MODIFIED, last_modified.httpdate)
        valid_cache ||= modified_match(last_modified)
      end
      
      # set cache-related headers
      cache(opts)
      
      # if not modified, we have a 304 response. Otherwise we yield to the
      # supplied block.
      valid_cache ? (@status = STATUS_NOT_MODIFIED) : yield(self)
    end
    
    COMMA = ','.freeze
    
    # Matches the supplied etag against any of the entities in the
    # If-None-Match header.
    def etag_match(etag)
      return false unless @request
      matches = @request.headers[IF_NONE_MATCH]
      if matches
        matches.split(COMMA).each do |e|
          return true if e.strip == etag
        end
      end
      false
    end
    
    # Matches the supplied last modified date against the If-Modified-Since
    # header.
    def modified_match(last_modified)
      return false unless @request
      if modified_since = @request.headers[IF_MODIFIED_SINCE]
        last_modified.to_i == Time.parse(modified_since).to_i
      else
        false
      end
    rescue => e
      raise BadRequestError, "Invalid value in If-Modified-Since header"
    end
    
    # Sets the Cache-Control header.
    def set_cache_control(directive)
      add_header(CACHE_CONTROL, directive)
    end
    
    def remove_cache_control
      @headers.reject! {|h| h =~ /^#{CACHE_CONTROL}/}
    end
  end
end

