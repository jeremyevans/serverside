module ServerSide::HTTP
  # HTTP Caching behavior
  module Caching
    # Sets caching-related headers and validates If-Modified-Since and
    # If-None-Match headers. If a match is found, a 304 response is sent.
    # Otherwise, the supplied block is invoked.
    def cache(opts)
      not_modified = false
      
      # check etag
      if etag = opts[:etag]
        etag = "\"#{etag}\""
        add_header(ETAG, etag) if etag
        not_modified = etag_match(etag)
      end
      
      # check last_modified
      if last_modified = opts[:last_modified]
        add_header(LAST_MODIFIED, last_modified)
        not_modified ||= modified_match(last_modified)
      end
      
      # check cache-control
      remove_cache_control
      if cache_control = opts[:cache_control]
        add_header(CACHE_CONTROL, cache_control)
      end
      
      # add an expires header
      if expires = opts[:expires]
        add_header(EXPIRES, expires.httpdate)
      elsif age = opts[:age]
        add_header(EXPIRES, (Time.now + age).httpdate)
      end
      
      # if not modified, send a 304 response. Otherwise we yield to the
      # supplied block.
      not_modified ? 
        send_response(STATUS_NOT_MODIFIED, nil) : yield
    end
    
    COMMA = ','.freeze
    
    # Matches the supplied etag against any of the entities in the
    # If-None-Match header.
    def etag_match(etag)
      matches = @request_headers[IF_NONE_MATCH]
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
      if modified_since = @request_headers[IF_MODIFIED_SINCE]
        last_modified.to_i == Time.parse(modified_since).to_i
      else
        false
      end
    rescue => e
      raise MalformedRequestError, "Invalid value in If-Modified-Since header"
    end
    
    # Sets the Cache-Control header.
    def set_cache_control(directive)
      add_header(CACHE_CONTROL, directive)
    end
    
    def remove_cache_control
      @response_headers.reject! {|h| h =~ /^#{CACHE_CONTROL}/}
    end
  end
end

