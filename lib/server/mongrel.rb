require 'mongrel'
require 'stringio'

# Additions and overrides for Mongrel code.
module Mongrel
  # Overrides for Mongrel::HttpResponse.
  class HttpResponse
    alias_method :orig_send_status, :send_status
    
    frozen :STREAM_STATUS_FORMAT => "HTTP/1.1 %d %s\r\nConnection: close\r\n"
  
    # Overrides the original method to send HTTP status without Content-Length
    # if @body is empty. This is used for streaming responses.
    def send_status(content_length = nil)
      return if @status_sent
      if (@body.length > 0) || content_length
        orig_send_status(content_length)
      else
        @socket.write(Frozen::STREAM_STATUS_FORMAT %
          [@status, HTTP_STATUS_CODES[@status]])
        @status_sent = true
      end
    end
  end
    
  class HttpServer
    # Overrides the original run method with code that's a bit simpler.
    def run
      BasicSocket.do_not_reverse_lookup = true
      @acceptor = Thread.new do
        begin
          while (client = @socket.accept)
            start = Time.now
            thread = Thread.new(client) do |c|
              begin
                process_client(c)
              rescue => e
                # log?
              end
            end
            thread[:started_on] = Time.now
            @workers.add(thread)
            sleep 0.001
          end
        rescue StopServer
          @socket.close if not @socket.closed?
          break
        rescue => e
          # log?
        end
      end
      return @acceptor
    end
    
    # Removes dead workers.
    def reap_dead_workers
      mark = Time.now
      @workers.list.each do |w|
        if mark - w[:started_on] > 60
          w.raise StopServer.new
        end
      end
    end
  end
end

module ServerSide
  # This class handles incoming Mongrel requests.
  class Handler < Mongrel::DirHandler
  
    frozen :CacheControl => 'Cache-Control', 
      :MaxAge => 'max-age=2592000' # 30 days

    # Processes incoming requests. If the specified path refers to a file in
    # public, the file is rendered. Otherwise, calls process_dynamic.
    def process(req, resp)
      path = req.params[Mongrel::Const::PATH_INFO]
      if (path =~ /^\/static\/(.*)/) || !process_dynamic(req, resp)
        begin
          fn = can_serve('/' + $1)
          if fn.nil? || File.directory?(fn)
            resp.start(404, true) do |head, out|
              out << "File not found: #{$1}"
            end
            return
          end
          resp.header[Frozen::CacheControl] = Frozen::MaxAge
          send_file(fn, req, resp)
        rescue => e
          Reality.log_error e
          begin
            resp.reset
            resp.start(403, true) do |head,out|
              out << "Error accessing file: #{e.message}"
            end
          rescue
            # At this stage there's nothing we can do anymore...
          end
        end
      end
    end
  
    # Processes dynamic requests.
    def process_dynamic(req, resp)
      Controller::Router.route(Controller::Request.new(
        req.body || StringIO.new, req.params, resp))
    rescue => e
      resp.start(200, true) do |head, out|
        out << e.message << "<br/>" << e.backtrace
      end
    end
  end
  
  def self.make_server(port)
    server = Mongrel::HttpServer.new('0.0.0.0', port)
    server.register('/', Handler.new(File.join(APP_ROOT, 'static')))
    periodically(60) {server.reap_dead_workers}
    server
  end
end

if $config[:mime_types]
  $config[:mime_types].each {|k, v| Mongrel::DirHandler.add_mime_type(k, v)}
end
