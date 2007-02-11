require 'time'

module ServerSide
  module HTTP
    # This module implements HTTP cache negotiation with a client.
    module Caching
      # HTTP headers
      ETAG = 'ETag'.freeze
      LAST_MODIFIED = 'Last-Modified'.freeze
      EXPIRES = 'Expires'.freeze
      CACHE_CONTROL = 'Cache-Control'.freeze
      VARY = 'Vary'.freeze
      
      IF_NONE_MATCH = 'If-None-Match'.freeze
      IF_MODIFIED_SINCE = 'If-Modified-Since'.freeze
      WILDCARD = '*'.freeze
      
      # Header values
      NO_CACHE = 'no-cache'.freeze
      IF_NONE_MATCH_REGEXP = /^"?([^"]+)"?$/.freeze
  
      # etags
      EXPIRY_ETAG_REGEXP = /(\d+)-(\d+)/.freeze
      EXPIRY_ETAG_FORMAT = "%d-%d".freeze
      ETAG_QUOTE_FORMAT = '"%s"'.freeze
    
      # 304 formats
      NOT_MODIFIED_CLOSE = "HTTP/1.1 304 Not Modified\r\nDate: %s\r\nConnection: close\r\nContent-Length: 0\r\n\r\n".freeze
      NOT_MODIFIED_PERSIST = "HTTP/1.1 304 Not Modified\r\nDate: %s\r\nContent-Length: 0\r\n\r\n".freeze

      # Sets the Cache-Control header to no-cache and removes any other 
      # caching-related headers in the response.      
      def disable_caching
        @response_headers[CACHE_CONTROL] = NO_CACHE
        @response_headers.delete(ETAG)
        @response_headers.delete(LAST_MODIFIED)
        @response_headers.delete(EXPIRES)
        @response_headers.delete(VARY)
      end
    
      # Returns an array containing all etag validators specified in the 
      # If-None-Match header.
      def etag_validators
        h = @headers[IF_NONE_MATCH]
        return [] unless h
        h.split(',').inject([]) do |m, i|
          i.strip =~ IF_NONE_MATCH_REGEXP ? (m << $1) : m
        end
      end
      
      # Returns true if any of the etag validators match etag, or if a wildcard
      # validator is present. Otherwise, if any of the validators is in an 
      # expiry etag format, checks whether etag has already expired.
      def valid_etag?(etag = nil)
        if etag
          etag_validators.each {|e| return true if e == etag || e == WILDCARD}
        else
          etag_validators.each do |e|
            return true if e == WILDCARD ||
              ((e =~ EXPIRY_ETAG_REGEXP) && (Time.at($2.to_i) > Time.now))
          end
        end
        nil
      end
      
      # Formats an expiry etag, which is composed of a modification stamp and
      # an expiration stamp in the future.
      def expiry_etag(stamp, max_age)
        EXPIRY_ETAG_FORMAT % [stamp.to_i, (Time.now + max_age).to_i]
      end

      # Returns true if the If-Modified-Since header matches stamp. 
      def valid_stamp?(stamp)
        return true if (modified_since = @headers[IF_MODIFIED_SINCE]) &&
          (modified_since == stamp.httpdate)
      end
      
      # Validates the client's cache by checking for any valid validators. If
      # so, a 304 response is rendered and true is returned. Otherwise, the 
      # supplied block is executed or nil is returned.
      def validate_cache(stamp, max_age, etag = nil, 
        cache_control = nil, vary = nil, &block)
        
        if valid_etag?(etag) || valid_stamp?(stamp)
          send_not_modified_response
          true
        else
          @response_headers[ETAG] = ETAG_QUOTE_FORMAT %
            [etag || expiry_etag(stamp, max_age)]
          @response_headers[LAST_MODIFIED] = stamp.httpdate
          @response_headers[EXPIRES] = (Time.now + max_age).httpdate
          @response_headers[CACHE_CONTROL] = cache_control if cache_control
          @response_headers[VARY] = vary if vary
          block ? block.call : nil
        end
      end
      
      def cache(max_age, &block)
        stamp = Time.now
        validate_cache(stamp, max_age, expiry_etag(stamp, max_age), &block)
      end

      # Renders a 304 not modified response.      
      def send_not_modified_response
        @socket << ((@persistent ? NOT_MODIFIED_PERSIST : NOT_MODIFIED_CLOSE) %
          Time.now.httpdate)
      end
    end
  end
end
