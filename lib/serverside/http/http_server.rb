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
    
    # include the Parsing, Response and Caching modules.
    include ServerSide::HTTP::Parsing
    include ServerSide::HTTP::Response
    include ServerSide::HTTP::Caching
    
    # attribute readers
    attr_reader :request_line, :method, :uri, :query, :http_version, :params
    attr_reader :content_length, :persistent, :request_headers
    attr_reader :request_cookies, :request_body

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
      # if an error is raised, we send an error response
      send_error_response(e) unless @state == :done
    end
    
    # set_state is called whenever a state transition occurs. It invokes the
    # state method.
    def set_state(s)
      @state = s
      send(s)
    rescue => e
      # if an error is raised, we send an error response
      send_error_response(e) unless @state == :done
    end
    
    # state_initial initializes @request_headers, @request_header_count,
    # @request_cookies and @response_headers. It immediately transitions to the 
    # request_line state.
    def state_initial
      # initialize request and response variables
      @request_line = nil
      @response_sent = false
      @request_headers = {}
      @request_header_count = 0
      @request_cookies = {}
      @response_headers = []
      @content_length = nil
      
      # immediately transition to the request_line state
      set_state(:state_request_line)
    end
  
    # state_request_line waits for the HTTP request line and parses it once it
    # arrives. If the request line is too big, an error is raised. The request
    # line supplies information including the 
    def state_request_line
      # check request line size
      if @in.size > MAX_REQUEST_LINE_SIZE
        raise MalformedRequestError, "Invalid request size"
      end
      if line = @in.get_line
        parse_request_line(line)
        # HTTP 1.1 connections are persistent by default.
        @persistent = @http_version == VERSION_1_1
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
          raise MalformedRequestError, "Invalid header size"
        # If the line empty then we move to the next state
        elsif line.empty?
          expecting_body = @content_length && (@content_length > 0)
          set_state(expecting_body ? :state_request_body : :state_response)
        else
          # check header count
          if (@request_header_count += 1) > MAX_HEADER_COUNT
            raise MalformedRequestError, "Too many headers"
          else
            parse_header(line)
          end
        end
      end
    end
      
    # state_request_body waits for the request body to arrive and then parses
    # the body. Once the body is parsed, the connection transitions to the 
    # response state.
    def state_request_body
      if @in.size >= @content_length
        @request_body = @in.slice!(0...@content_length)
        parse_request_body(@request_body)
        set_state(:state_response)
      end
    end
    
    # state_response invokes the handle method. If no response was sent, an
    # error is raised. After the response is sent, the connection is either
    # closed or goes back to the initial state.
    def state_response
      handle
      unless @response_sent || @streaming
        raise "No handler found for this URI (#{@uri})"
      end
    ensure
      unless @streaming
        set_state(@persistent ? :state_initial : :state_done)
      end
    end
    
    # state_done closes the connection.
    def state_done
      close_connection_after_writing
    end
    
    # periodically implements a periodical timer. The timer is invoked until
    # the supplied block returns false or nil.
    def periodically(period, &block)
      EventMachine::add_timer(period) do
        if block.call
          periodically(period, &block)
        end
      end
    end

    # periodically implements a periodical timer. The timer is invoked until
    # the supplied block returns false or nil.
    def streaming_periodically(period, &block)
      @streaming = true
      if block.call # invoke block for the first time
        EventMachine::add_timer(period) do
          if block.call
            streaming_periodically(period, &block)
          else
            set_state(@persistent ? :state_initial : :state_done)
          end
        end
      else
        set_state(@persistent ? :state_initial : :state_done)
      end
    end
  end
end