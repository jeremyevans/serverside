module Controller
  # This class encapsulates incoming HTTP requests. It also holds the response.
  class Request
    attr_accessor :req, :env, :stamp, :response
    attr_accessor :method, :path, :cookie_jar, :params, :remote_ip, :body
    attr_accessor :status, :headers
    attr_reader :cache_expiration
    
    attr_accessor :controller
    
    # Initializes a new instance by preparing all instance variables, parsing
    # the request parameters, POST body, and setting up initial status and
    # headers.
    
    class Const
      def self.const_missing(name)
        const_set(name, name.to_s.freeze)
      end
      
      CacheControl = 'Cache-Control'.freeze
      NoCache = 'no-cache'.freeze
      UrlEncoded = 'application/x-www-form-urlencoded'.freeze
      ContentType = 'Content-Type'.freeze
      TextHtml = 'text/html'.freeze
    end
    
    def initialize(req, env, response)
      @stamp = Time.now
      @req = req
      @env = env
      @response = response
      
      @method = (env[Const::REQUEST_METHOD] || Const::GET).downcase.to_sym
      @path = env[Const::PATH_INFO]
      @remote_ip = env[Const::REMOTE_ADDR]
      #@cookie_jar = CookieJar.new(env['HTTP_COOKIE'])
      @params = parse_parameters(env[Const::QUERY_STRING])
      parse_post_body if @method == :post

      @status = 200
      @headers = {Const::CacheControl => Const::NoCache}
    end
    
    def [](var)
      instance_variable_get("@#{var}")
    end

    # Parses the POST body.
    # Shamelessly appropriated from Why the Lucky Stiff's Camping framework.
    def parse_post_body
      inp = @req.read(@env[Const::CONTENT_LENGTH].to_i)
      if %r|\Amultipart/form-data.*boundary=\"?([^\";,]+)|n.match(@env[Const::CONTENT_TYPE])
        b = "--#$1"
        inp.split(/(?:\r?\n|\A)#{Regexp::quote(b)}(?:--)?\r\n/m).each {|pt|
          h, v = pt.split("\r\n\r\n",2)
          fh = {}
          [:name, :filename].each {|x|
            fh[x] = $1 if h =~ /^Content-Disposition: form-data;.*(?:\s#{x}="([^"]+)")/m
          }
          fn = fh[:name]
          if fh[:filename]
            fh[:type] = $1 if h =~ /^Content-Type: (.+?)(\r\n|\Z)/m
            fh[:tempfile] = Tempfile.new(:upload).instance_eval {binmode; write v; rewind; self}
          else
            fh = v
          end
          @params[fn] = fh if fn
        }
      else
        if @env[Const::CONTENT_TYPE] == Const::UrlEncoded
          @params.merge!(parse_parameters(inp))
          @body = @params[:body]
        else
          @body = inp
        end
      end
    end

    # Parses URI parameters and returns a hash containing all parameters.
    def parse_parameters(s)
      return {} if s.nil?
      s.split(/[&;] */n).inject({}) {|result, part|
        k, v = part.split('=', 2)
        result[k.to_sym] = (v || '').uri_unescape
        result
      }
    end

    # Send headers to client. 
    def send_headers(body = nil)
      @headers_rendered = true
      #@headers['Set-Cookie'] = @cookie_jar.compose unless @cookie_jar.empty?
      @response.start(@status, true) do |h, b|
        @headers.each {|k, v| [*v].each {|vi| h[k] = vi}}
        b << body if body
      end
    end
    
    # Renders a response with content type.    
    def render(body, content_type = Const::TextHtml)
      unless @headers_rendered
        @headers[Const::ContentType] = content_type
        send_headers(body)
      else
        @response.write(body)
      end
    end
    
    def stream(body, content_type = Const::TextHtml)
      unless @headers_rendered
        @headers[Const::ContentType] = content_type
        send_headers
      end
      @response.write(body)
    end
    
    # Renders a 302 response.
    def redirect(uri)
      @status = 302
      @headers = {Const::Location => uri}
      send_headers
    end

    # Sets the cache expiration stamp. This is used both for server-side caching
    # (implemented using RealityController::Cache) and client-side using the
    # Cache-Control HTTP header.
    def cache_expiration=(stamp)
      @cache_expiration = stamp
      if stamp.nil?
        headers[Const::CacheControl] = Const::NoCache
      else
        headers[Const::CacheControl] = "max-age=#{stamp - Time.now}"
      end
    end
  end
end