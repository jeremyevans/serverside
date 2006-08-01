unless defined?(APP_ROOT)
  root_path = File.join(File.dirname(__FILE__), '..')
  unless RUBY_PLATFORM =~ /mswin32/
    require 'pathname'
    root_path = Pathname.new(root_path).cleanpath(true).to_s
  end
  APP_ROOT = File.expand_path(root_path)
end

# Kernel extensions and overrides.
module Kernel
  # Requires all code files in a directory.
  def require_all(path)
    path = File.join(APP_ROOT, path) unless File.directory?(path)
    return unless File.directory?(path)
    Dir.foreach(path) do |fn|
      if fn =~ /\.rb$/
        require File.join(path, fn)
      end
    end
  end

  alias_method :orig_require, :require
  
  # Attempts to load the module from one of the LOAD_PATHS, or else calls
  # the original require method.
  def require(name)
    fn = (name =~ /\.rb$/) ? name : name + '.rb'
    qualified = File.join(APP_ROOT, fn)
    return orig_require(qualified) if File.file?(qualified)
    orig_require(name)
  end
end



require "#{APP_ROOT}/config/environment"
