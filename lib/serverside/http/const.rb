module ServerSide::HTTP
  # HTTP versions
  VERSION_1_0 = '1.0'.freeze
  VERSION_1_1 = '1.1'.freeze
  
  # maximum sizes
  # compare to http://mongrel.rubyforge.org/security.html
  MAX_REQUEST_LINE_SIZE = 1024
  MAX_HEADER_SIZE = 112 * 1024 # 112KB
  MAX_HEADER_NAME_SIZE = 256
  MAX_HEADER_COUNT = 256 # should be enough methinks
  MAX_PARAMETER_VALUE_SIZE = 10240 # 10KB
  MAX_PARAMETER_NAME_SIZE = 64 # should be enough
  
  # request body and response body
  CONTENT_LENGTH = 'Content-Length'.freeze
  CONTENT_TYPE = 'Content-Type'.freeze
  MULTIPART_FORM_DATA_RE = /^multipart\/form-data; boundary=(.+)$/.freeze
  CONTENT_DISPOSITION = 'Content-Disposition'.freeze
  DISPOSITION_FORM_DATA_RE = /^form-data; name="([^"]+)"(; filename="([^"]+)")?$/.freeze
  FORM_URL_ENCODED = 'application/x-www-form-urlencoded'.freeze
  
  # connection
  CONNECTION = 'Connection'.freeze
  KEEP_ALIVE = 'keep-alive'.freeze
  CLOSE = 'close'.freeze
  CONNECTION_CLOSE = "Connection: close\r\n".freeze
  
  # headers
  HOST = 'Host'.freeze
  X_FORWARDED_FOR = 'X-Forwarded-For'.freeze
  DATE = 'Date'.freeze
  LOCATION = 'Location'.freeze
  ACCEPT = 'Accept'.freeze
  USER_AGENT = 'User-Agent'.freeze
  
  # caching
  IF_NONE_MATCH = 'If-None-Match'.freeze
  IF_MODIFIED_SINCE = 'If-Modified-Since'.freeze
  ETAG = 'ETag'.freeze
  LAST_MODIFIED = 'Last-Modified'.freeze
  CACHE_CONTROL = 'Cache-Control'.freeze
  NO_CACHE = 'no-cache'.freeze
  EXPIRES = 'Expires'.freeze
  
  # response status
  STATUS_OK = '200 OK'.freeze
  STATUS_CREATED = '201 Created'.freeze
  STATUS_ACCEPTED = '202 Accepted'.freeze
  STATUS_NO_CONTENT = '204 No Content'.freeze
  
  STATUS_MOVED_PERMANENTLY = '301 Moved Permanently'.freeze
  STATUS_FOUND = '302 Found'.freeze
  STATUS_NOT_MODIFIED = '304 Not Modified'.freeze

  STATUS_BAD_REQUEST = '400 Bad Request'.freeze
  STATUS_UNAUTHORIZED = '401 Unauthorized'.freeze
  STATUS_FORBIDDEN = '403 Forbidden'.freeze
  STATUS_NOT_FOUND = '404 Not Found'.freeze
  STATUS_METHOD_NOT_ALLOWED = '405 Method Not Allowed'.freeze
  STATUS_NOT_ACCEPTABLE = '406 Not Acceptable'.freeze
  STATUS_CONFLICT = '409 Conflict'.freeze
  STATUS_REQUEST_ENTITY_TOO_LARGE = '413 Request Entity Too Large'.freeze
  STATUS_REQUEST_URI_TOO_LONG = '414 Request-URI Too Long'.freeze
  STATUS_UNSUPPORTED_MEDIA_TYPE = '415 Unsupported Media Type'.freeze
  
  STATUS_INTERNAL_SERVER_ERROR = '500 Internal Server Error'.freeze
  STATUS_NOT_IMPLEMENTED = '501 Not Implemented'.freeze
  STATUS_SERVICE_UNAVAILABLE = '503 Service Unavailable'.freeze
  
  # cookies
  COOKIE = 'Cookie'.freeze
  SET_COOKIE = 'Set-Cookie'.freeze
  COOKIE_EXPIRED_TIME = Time.at(0).freeze
end