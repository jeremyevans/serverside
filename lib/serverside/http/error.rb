# StandardError extensions.
class StandardError
  # Returns the HTTP status code associated with the error class.
  def http_status
    ServerSide::HTTP::STATUS_INTERNAL_SERVER_ERROR
  end
  
  # Sets the HTTP status code associated with the error class.
  def self.set_http_status(value)
    define_method(:http_status) {value}
  end
end

module ServerSide::HTTP
  # This error is raised when a malformed request is encountered.
  class MalformedRequestError < RuntimeError
    set_http_status STATUS_BAD_REQUEST
  end
  
  # This error is raised when an invalid file is referenced.
  class FileNotFoundError <  RuntimeError
    set_http_status STATUS_NOT_FOUND
  end
end