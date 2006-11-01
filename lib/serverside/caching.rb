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
      IF_MODIFIED_SINCE = 'Id-Modified-Since'.freeze
      WILDCARD = '*'.freeze
      
      # Header values
      NO_CACHE = 'no-cache'.freeze
      IF_NONE_MATCH_REGEXP = /^"?([^"]+)"?$/.freeze
  
      # expiry etag
      ETAG_EXPIRY_REGEXP = /(\d+)-(\d+)/.freeze
      ETAG_EXPIRY_FORMAT = "%d-%d".freeze
    
      # 304 formats
      NOT_MODIFIED_CLOSE = "HTTP/1.1 304 Not Modified\r\nDate: %s\r\nConnection: close\r\nContent-Length: 0r\n\r\n".freeze
      NOT_MODIFIED_PERSIST = "HTTP/1.1 304 Not Modified\r\nDate: %s\r\nContent-Length: 0\r\n\r\n".freeze
      
      def disable_caching
        @response_headers[CACHE_CONTROL] = NO_CACHE
        @response_headers.delete(ETAG)
        @response_headers.delete(LAST_MODIFIED)
        @response_headers.delete(EXPIRES)
        @response_headers.delete(VARY)
      end
    
      def etag_validators
        h = @headers[IF_NONE_MATCH]
        return [] unless h
        h.split(',').inject([]) do |m, i|
          i.strip =~ IF_NONE_MATCH_REGEXP ? (m << $1) : m
        end
      end
      
      def valid_etag?(etag = nil)
        if etag
          etag_validators.each {|e| return true if e == etag || e == WILDCARD}
        else
          etag_validators.each do |e|
            if e =~ EXPIRY_ETAG_REGEXP
              return true if Time.at($2) < Time.now
            end
          end
        end
        nil
      end
      
      def expiry_etag(stamp, max_age)
        EXPIRY_ETAG_FORMAT % [stamp.to_i, (stamp + max_age).to_i]
      end
      
      def valid_stamp?(stamp)
        if modified_since = @headers[IF_MODIFIED_SINCE]
          modified_since == stamp.httpdate
        end
      end
      
      def validate_cache(stamp, max_age, etag = nil, 
        cache_control = nil, vary = nil, &block)
        
        if valid_etag?(etag) || valid_stamp?(stamp)
          send_not_modified_response
          true
        else
          @response_headers[ETAG] = "\"#{etag || expiry_etag(stamp, max_age)}\""
          @response_headers[LAST_MODIFIED] = stamp.httpdate
          @response_headers[EXPIRES] = (stamp + max_age).httpdate
          @response_headers[CACHE_CONTROL] = cache_control if cache_control
          @response_headers[VARY] = vary if vary
          block ? block.call : nil
        end
      end
      
      def send_not_modified_response
        @socket << ((@persistent ? NOT_MODIFIED_PERSIST : NOT_MODIFIED_CLOSE) %
          Time.now.httpdate)
      end
    end
  end
end
