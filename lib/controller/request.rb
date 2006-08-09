module Controller
  # This class encapsulates incoming HTTP requests. It also holds the response.
  class Request
    attr_accessor :req, :env, :stamp, :response, :method, :path, :host, 
      :cookie_jar, :params, :remote_ip, :body, :status, :headers
    attr_reader :cache_expiration
    
    frozen :CacheControl => 'Cache-Control',
      :NoCache => 'no-cache',
      :UrlEncoded => 'application/x-www-form-urlencoded',
      :ContentType => 'Content-Type',
      :TextHtml => 'text/html'
      
    # Initializes a new instance by preparing all instance variables, parsing
    # the request parameters, POST body, and setting up initial status and
    # headers.
    def initialize(req, env, response)
      @stamp = Time.now
      @req = req
      @env = env
      @response = response
      
      @method = (env[Frozen::REQUEST_METHOD] || Frozen::GET).downcase.to_sym
      @path = env[Frozen::PATH_INFO]
      @host = env[Frozen::HTTP_HOST]
      @remote_ip = env[Frozen::REMOTE_ADDR]
      #@cookie_jar = CookieJar.new(env['HTTP_COOKIE'])
      @params = parse_parameters(env[Frozen::QUERY_STRING])
      parse_post_body if @method == :post

      @status = 200
      @headers = {Frozen::CacheControl => Frozen::NoCache}
    end
    
    def [](var)
      send(var)
    end
    
    def set_param(name, value)
      @params[name] = value
    end
    
    frozen :MultipartRegexp => (/\Amultipart\/form-data.*boundary=\"?([^\";,]+)/n),
      :DoubleLineEnd => "\r\n\r\n"
    
    # Parses the POST body.
    # Shamelessly appropriated from Why the Lucky Stiff's Camping framework.
    def parse_post_body
      inp = @req.read(@env[Frozen::CONTENT_LENGTH].to_i)
      if @env[Frozen::CONTENT_TYPE] =~ Frozen::MultipartRegexp
        boundary = "--#$1"
        inp.split(/(?:\r?\n|\A)#{Regexp::quote(boundary)}(?:--)?\r\n/m).each do |pt|
          h, v = pt.split(Frozen::DoubleLineEnd, 2)
          fh = {}
          [:name, :filename].each do |x|
            fh[x] = $1 if
              h =~ /^Content-Disposition: form-data;.*(?:\s#{x}="([^"]+)")/m
          end
          fn = fh[:name]
          if fh[:filename]
            fh[:type] = $1 if h =~ /^Content-Type: (.+?)(\r\n|\Z)/m
            fh[:tempfile] = Tempfile.new(:upload).instance_eval do
              binmode; write v; rewind; self
            end
          else
            fh = v
          end
          @params[fn] = fh if fn
        end
      else
        if @env[Frozen::CONTENT_TYPE] == Frozen::UrlEncoded
          @params.merge!(parse_parameters(inp))
          @body = @params[:body]
        else
          @body = inp
        end
      end
    end
    
    frozen :EqualSign => '=', :ParameterRegexp => /[&;] */n, :EmptyString => ''

    # Parses URI parameters and returns a hash containing all parameters.
    def parse_parameters(s)
      return {} if s.nil?
      s.split(Frozen::ParameterRegexp).inject({}) {|result, part|
        k, v = part.split(Frozen::EqualSign, 2)
        result[k.to_sym] = (v || Frozen::EmptyString).uri_unescape
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
    def render(body, content_type = Frozen::TextHtml)
      unless @headers_rendered
        @headers[Frozen::ContentType] = content_type
        send_headers(body)
      else
        @response.write(body)
      end
    end
    
    def stream(body, content_type = Frozen::TextHtml)
      unless @headers_rendered
        @headers[Frozen::ContentType] = content_type
        send_headers
      end
      @response.write(body)
    end
    
    # Renders a 302 response.
    def redirect(uri)
      @status = 302
      @headers = {Frozen::Location => uri}
      send_headers
    end

    # Sets the cache expiration stamp. This is used both for server-side caching
    # (implemented using RealityController::Cache) and client-side using the
    # Cache-Control HTTP header.
    def cache_expiration=(stamp)
      @cache_expiration = stamp
      if stamp.nil?
        headers[Frozen::CacheControl] = Frozen::NoCache
      else
        headers[Frozen::CacheControl] = "max-age=#{stamp - Time.now}"
      end
    end
  end
end
