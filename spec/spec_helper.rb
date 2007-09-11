require File.join(File.dirname(__FILE__), '../lib/serverside')

include ServerSide::HTTP

class Request
  attr_writer :persistent
end

class SpecHTTPServer
  include Server
  
  attr_accessor :in, :state
  
  def initialize
    reset
  end
  
  def reset
    post_init
    @response = ''
    @response_headers = []
    @closed = false
  end
  
  attr_accessor :response, :closed
  
  def send_data(data)
    @response << data
  end
  
  def close_connection_after_writing
    @closed = true
  end
  
  def handle_error(e)
    raise e
  end
end

