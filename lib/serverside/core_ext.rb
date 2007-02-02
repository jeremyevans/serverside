# String extension methods.
class String
  # Encodes a normal string to a URI string.
  def uri_escape
    gsub(/([^ a-zA-Z0-9_.-]+)/n) {'%'+$1.unpack('H2'*$1.size).
      join('%').upcase}.tr(' ', '+')
  end
  
  # Decodes a URI string to a normal string.
  def uri_unescape
    tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n){[$1.delete('%')].pack('H*')}
  end
  
  def html_escape
    gsub(/&/, "&amp;").gsub(/\"/, "&quot;").gsub(/>/, "&gt;").gsub(/</, "&lt;")
  end
  
  # Concatenates a path (do we really need this sugar?)
  def /(o)
    File.join(self, o.to_s)
  end

  # Converts camel-cased phrases to underscored phrases.
  def underscore
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").downcase
  end
  
  # Converts an underscored name into a camelized name
  def camelize
    gsub(/(^|_)(.)/) {$2.upcase}
  end
end

# Symbol extensions and overrides.
class Symbol
  #
  def /(o)
    File.join(self, o.to_s)
  end
end

class Proc
  # Returns a unique proc tag. This method is used by the router.
  def proc_tag
    'proc_' + object_id.to_s(36).sub('-', '_')
  end
end

class Object
  # Returns a unique tag for the object. This method is used by the router.
  def const_tag
    'C' + object_id.to_s(36).upcase.sub('-', '_')
  end
end

def true.to_i; -1; end
def false.to_i; 0; end
