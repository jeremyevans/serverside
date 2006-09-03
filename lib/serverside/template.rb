require 'erb'

module ServerSide
  # The Template module implements an ERB template rendering system. Templates
  # are cached and automatically reloaded if the file changes.
  class Template
    # The @@templates variable is a hash keyed by template name. The values are
    # arrays containing 2 objects: a file stamp (if the template comes from a 
    # file,) and the template object itself.  
    @@templates = {}
    
    # Stores a template for later use. The stamp parameter is used only when
    # the content of a template file is stored.
    def self.set(name, body, stamp = nil)
      @@templates[name] = [stamp, ERB.new(body)]
    end

    # Renders a template. If the template name is not found, attemps to load
    # the template from file. If the template has a non-nil stamp, the render
    # method compares it to the file stamp, and reloads the template content
    # if necessary.
    def self.render(name, binding)
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
