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
  
  # Concatenates a path (do we really need this sugar?)
  def /(o)
    File.join(self, o.to_s)
  end
end

# Symbol extensions and overrides.
class Symbol
  # A faster to_s method. This is called a lot, and memoization gives us
  # performance between 10%-35% better.
  def to_s
    @_to_s || (@_to_s = id2name)
  end
end