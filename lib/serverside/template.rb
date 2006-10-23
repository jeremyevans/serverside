require 'erb'

module ServerSide
  # The Template module implements an ERB template rendering system. Templates
  # are cached and automatically reloaded if the file changes.
  class Template
    # The @@templates variable caches templates in use. The values are
    # arrays containing 2 objects: a file stamp (if the template comes from a 
    # file,) and the template object itself.
    @@templates = {}
    
    # Caches a template for later use. The stamp parameter is used only when
    # the content of a template file is stored.
    def self.set(name, body, stamp = nil)
      @@templates[name] = [stamp, ERB.new(body)]
    end

    # Validates the referenced template by checking its stamp. If the name
    # refers to a file, its stamp is checked against the cache stamp, and it
    # is reloaded if necessary. The function returns an ERB instance or nil if
    # the template is not found.
    def self.validate(name)
      t = @@templates[name]
      return t[1] if t && t[0].nil?
      if File.file?(name)
        stamp = File.mtime(name)
        t = set(name, IO.read(name), stamp) if (!t || (stamp != t[0]))
        t[1]
      else
        @@templates[name] = nil
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
      t = @@templates[name]
      return t[1].result(binding) if t && t[0].nil?
      
      if File.file?(name)
        stamp = File.mtime(name)
        t = set(name, IO.read(name), stamp) if (!t || (stamp != t[0]))
        t[1].result(binding)
      else
        @@templates[name] = nil
        raise RuntimeError, 'Template not found.'
      end
    end
  end
end
