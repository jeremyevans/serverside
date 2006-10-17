require 'time'

module ServerSide
  module HTTP
    # This module implements HTTP cache negotiation with a client.
    module Caching
      ETAG = 'ETag'.freeze
      CACHE_CONTROL = 'Cache-Control'.freeze
      DEFAULT_MAX_AGE = (86400 * 30).freeze
      IF_NONE_MATCH = 'If-None-Match'.freeze
      ETAG_WILDCARD = '*'.freeze
      IF_MODIFIED_SINCE = 'If-Modified-Since'.freeze
      LAST_MODIFIED = "Last-Modified".freeze
      NOT_MODIFIED_CLOSE = "HTTP/1.1 304 Not Modified\r\nDate: %s\r\nConnection: close\r\nLast-Modified: %s\r\nETag: \"%s\"\r\nCache-Control: max-age=%d\r\n\r\n".freeze
      NOT_MODIFIED_PERSIST = "HTTP/1.1 304 Not Modified\r\nDate: %s\r\nLast-Modified: %s\r\nETag: \"%s\"\r\nCache-Control: max-age=%d\r\n\r\n".freeze
      MAX_AGE = 'max-age=%d'.freeze
      IF_NONE_MATCH_REGEXP = /^"?([^"]+)"?$/.freeze

      # Returns an array containing all etags specified by the client in the
      # If-None-Match header.
      def cache_etags
        h = @headers[IF_NONE_MATCH]
        return [] unless h
        h.split(',').inject([]) do |m, i|
          i.strip =~ IF_NONE_MATCH_REGEXP ? (m << $1) : m
        end
      end
      
      # Returns the cache stamp specified by the client in the 
      # If-Modified-Since header. If no stamp is specified, returns nil.
      def cache_stamp
        (h = @headers[IF_MODIFIED_SINCE]) ? Time.httpdate(h) : nil
      rescue
        nil
      end

      # Checks the request headers for validators and returns true if the
      # client cache is valid. The validators can be either etags (specified
      # in the If-None-Match header), or a modification stamp (specified in the
      # If-Modified-Since header.)
      def valid_client_cache?(etag, http_stamp)
        none_match = @headers[IF_NONE_MATCH]
        modified_since = @headers[IF_MODIFIED_SINCE]
        (none_match && (none_match =~ /\*|"#{etag}"/)) ||
          (modified_since && (modified_since == http_stamp))
      end
      
      # Validates the client cache by checking any supplied validators in the
      # request. If the client cache is not valid, the specified block is
      # executed. This method also makes sure the correct validators are 
      # included in the response - along with a Cache-Control header, to allow
      # the client to cache the response. A possible usage:
      # 
      #   validate_cache("1234-5678", Time.now, 360) do
      #     send_response(200, "text/html", body)
      #   end
      def validate_cache(etag, stamp, max_age = DEFAULT_MAX_AGE, &block)
        http_stamp = stamp.httpdate
        if valid_client_cache?(etag, http_stamp)
          send_not_modified(etag, http_stamp, max_age)
        else
          @response_headers[ETAG] = "\"#{etag}\""
          @response_headers[LAST_MODIFIED] = http_stamp
          @response_headers[CACHE_CONTROL] = MAX_AGE % max_age
          block.call
        end
      end

      # Sends a 304 HTTP response, along with etag and stamp validators, and a
      # Cache-Control header.
      def send_not_modified(etag, http_time, max_age = DEFAULT_MAX_AGE)
        @socket << ((@persistent ? NOT_MODIFIED_PERSIST : NOT_MODIFIED_CLOSE) % 
          [Time.now.httpdate, http_time, etag, max_age])
      end
    end
  end
end

__END__
