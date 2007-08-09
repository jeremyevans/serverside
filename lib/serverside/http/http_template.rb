require 'rubygems'
require 'erubis'

module ServerSide::HTTP
  module Template
    TEMPLATES = {}
    
    # Caches a template for later use. The stamp parameter is used only when
    # the content of a template file is stored.
    def self.set(name, body, stamp = nil)
      TEMPLATES[name] = [stamp, Erubis::Eruby.new(body)]
    end

    # Validates the referenced template by checking its stamp. If the name
    # refers to a file, its stamp is checked against the cache stamp, and it
    # is reloaded if necessary. The function returns an ERB instance or nil if
    # the template is not found.
    def self.validate(name)
      t = TEMPLATES[name]
      return t[1] if t && t[0].nil?
      fn = name.to_s
      if File.file?(fn)
        stamp = File.mtime(fn)
        t = set(name, IO.read(fn), stamp) if (!t || (stamp != t[0]))
        t[1]
      else
        TEMPLATES[name] = nil
      end
    end

    # Renders a template by first validating it, and by invoking it with the
    # supplied binding.
    def self.render(name, binding)
      if template = validate(name)
        template.result(binding)
      else
        raise RuntimeError, 'Template not found.'
      end
    end
  end
end
