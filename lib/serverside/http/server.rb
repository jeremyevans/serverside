require 'rubygems'
require 'eventmachine'
require 'time'

# Use epoll if available
EventMachine.epoll

module ServerSide::HTTP
  # The HTTP server is implemented as a simple state-machine with the following
  # states:
  # state_initial - initialize request variables.
  # state_request_line - wait for and parse the request line.
  # state_request_headers - wait for and parse header lines.
  # state_request_body - wait for and parse the request body.
  # state_response - send a response.
  # state_done - the connection is closed.
  #
  # The server supports persistent connections (if the request is in HTTP 1.1).
  # In that case, after responding to the request the state is changed back to
  # request_line.
  module Server
    # Creates a new server module
    def self.new
      Module.new do
        # include the HTTP state machine and everything else
        include ServerSide::HTTP::Server
        
        # define a start method for starting the server
        def self.start(addr, port)
          EventMachine::run do
            EventMachine::start_server addr, port, self
          end
        end
        
        # invoke the supplied block for application-specific behaviors.
        yield
      end
    end
    
    # attribute readers
    attr_reader :request, :response_sent

    # post_init creates a new @in buffer and sets the connection state to 
    # initial.
    def post_init
      # initialize the in buffer
      @in = ''
      
      # set state to initial
      set_state(:state_initial)
    end
    
    # receive_data is a callback invoked whenever new data is received on the
    # connection. The incoming data is added to the @in buffer and the state
    # method is invoked.
    def receive_data(data)
      @in << data
      send(@state)
    rescue => e
      handle_error(e)
    end
    
    # set_state is called whenever a state transition occurs. It invokes the
    # state method.
    def set_state(s)
      @state = s
      send(s)
    rescue => e
      handle_error(e)
    end

    # Handle errors raised while processing a request
    def handle_error(e)
      # if an error is raised, we send an error response
      unless @response_sent || @streaming
        send_response(Response.error(e))
      end
    end
    
    # state_initial creates a new request instance and immediately transitions
    # to the request_line state.
    def state_initial
      @request = ServerSide::HTTP::Request.new(self)
      @response_sent = false
      set_state(:state_request_line)
    end
  
    # state_request_line waits for the HTTP request line and parses it once it
    # arrives. If the request line is too big, an error is raised. The request
    # line supplies information including the 
    def state_request_line
      # check request line size
      if line = @in.get_line
        if line.size > MAX_REQUEST_LINE_SIZE
          raise BadRequestError, "Invalid request size"
        end
        @request.parse_request_line(line)
        set_state(:state_request_headers)
      end
    end
  
    # state_request_headers parses each header as it arrives. If too many
    # headers are included or a header exceeds the maximum header size,
    # an error is raised.
    def state_request_headers
      while line = @in.get_line
        # Check header size
        if line.size > MAX_HEADER_SIZE
          raise BadRequestError, "Invalid header size"
        # If the line empty then we move to the next state
        elsif line.empty?
          expecting_body = @request.content_length.to_i > 0
          set_state(expecting_body ? :state_request_body : :state_response)
        else
          @request.parse_header(line)
        end
      end
    end
      
    # state_request_body waits for the request body to arrive and then parses
    # the body. Once the body is parsed, the connection transitions to the 
    # response state.
    def state_request_body
      if @in.size >= @request.content_length
        @request.parse_body(@in.slice!(0...@request.content_length))
        set_state(:state_response)
      end
    end
    
    # state_response invokes the handle method. If no response was sent, an
    # error is raised. After the response is sent, the connection is either
    # closed or goes back to the initial state.
    def state_response
      unless resp = handle(@request)
        raise "No handler found for this URI (#{@request.url})"
      end
      send_response(resp)
    end
    
    def send_response(resp)
      unless persist = @request.persistent && resp.persistent?
        resp.headers << CONNECTION_CLOSE
      end
      if resp.should_render?
        send_data(resp.to_s)
      end
      if resp.streaming?
        start_stream_loop(resp.stream_period, resp.stream_proc)
      else
        set_state(persist ? :state_initial : :state_done)
      end
    end
    
    # state_done closes the connection.
    def state_done
      close_connection_after_writing
    end
    
    # starts implements a periodical timer. The timer is invoked until
    # the supplied block returns false or nil. When the 
    def start_stream_loop(period, block)
      @streaming = true
      if block.call(self)
        EventMachine::add_timer(period) {start_stream_loop(period, block)}
      else
        set_state(:state_done)
      end
    end
  end
end