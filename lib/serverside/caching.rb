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

      def valid_client_cache?(etag, http_stamp)
        none_match = @headers[IF_NONE_MATCH]
        modified_since = @headers[IF_MODIFIED_SINCE]
        (none_match && (none_match =~ /\*|"#{etag}"/)) ||
          (modified_since && (modified_since == http_stamp))
      end
      
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

      def send_not_modified(etag, http_time, max_age = DEFAULT_MAX_AGE)
        @socket << ((@persistent ? NOT_MODIFIED_PERSIST : NOT_MODIFIED_CLOSE) % 
          [Time.now.httpdate, http_time, etag, max_age])
      end
    end          
  end
end

__END__

Reality::Controller.new(:node_history) do
  default_flavor :html
  valid_method :get
  
  def html
    validate_cache(etag, http_time) {|cache_headers|
      render_template(cache_headers)
    }
  end
end
