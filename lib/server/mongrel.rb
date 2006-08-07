require 'stringio'
require 'rubygems'
require 'mongrel'

# Additions and overrides for Mongrel code.
module Mongrel
  # Additional mongrel constants.
  module Const
    # HTTP status format without Content-Length (for streaming responses). 
    STREAM_STATUS_FORMAT =
      "HTTP/1.1 %d %s\r\nConnection: close\r\n".freeze
  end

  # Overrides for Mongrel::HttpResponse.
  class HttpResponse
    alias_method :orig_send_status, :send_status
  
    # Overrides the original method to send HTTP status without Content-Length
    # if @body is empty. This is used for streaming responses.
    def send_status(content_length = nil)
      return if @status_sent
      if (@body.length > 0) || content_length
        orig_send_status(content_length)
      else
        @socket.write(Const::STREAM_STATUS_FORMAT %
          [@status, HTTP_STATUS_CODES[@status]])
        @status_sent = true
      end
    end
  end
    
  # Overrides for Mongrel::DirHandler.
  class DirHandler
    # Overrides the origianl method to remove the ETAG check and other crap.
    def send_file(req_path, request, response, header_only=false)
      stat = File.stat(req_path)
      response.status = 200
      dot_at = req_path.rindex('.')
      if dot_at
        response.header[Const::CONTENT_TYPE] = 
          MIME_TYPES[req_path[dot_at .. -1]] || @default_content_type
      end

      # send a status with content length
      response.send_status(stat.size)
      response.send_header
      response.send_file(req_path) unless header_only
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
          w.raise StopServer.new("Timed out.")
        end
      end
    end
  end
end

# This class handles incoming Mongrel requests.
class ServerSideHandler < Mongrel::DirHandler

  # Processes incoming requests. If the specified path refers to a file in
  # public, the file is rendered. Otherwise, calls process_dynamic.
  def process(req, resp)
    path = req.params[Mongrel::Const::PATH_INFO]
    unless path =~ /^\/static\/(.*)/
      process_dynamic(req, resp)
    else
      begin
        fn = can_serve('/' + $1)
        if fn.nil? || File.directory?(fn)
          resp.start(404) do |head, out|
            out << "File not found: #{$1}"
          end
          return
        end
        resp.header['Cache-Control'] = 'max-age=2592000' # 30 days
        send_file(fn, req, resp)
      rescue => e
        Reality.log_error e
        begin
          resp.reset
          resp.start(403) do |head,out|
            out << "Error accessing file: #{e.full_info}"
          end
        rescue
          # At this stage there's nothing we can do anymore...
        end
      end
    end
  end

  HTML = '<html><body>Hello there!</body></html>'.freeze  
  
  # Processes dynamic requests.
  def process_dynamic(req, resp)
    begin
      request = Controller::Request.new(req.body || StringIO.new(''), 
        req.params, resp)
      request.render(HTML)
    rescue => e
      resp.start(200) do |head, out|
        out << e.message << "<br/>" << e.backtrace
      end
    end
  end
end

if $config[:mime_types]
  $config[:mime_types].each {|k, v| Mongrel::DirHandler.add_mime_type(k, v)}
end
