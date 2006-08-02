# Symbol extension methods.
class Symbol
  # Converts the symbol into a Proc instance that calls a method referenced by
  # the symbol on the yielded object.
  #
  # Thus we can do stuff like:
  # [1, 2, 3].map(&:to_s)
  #
  # instead of:
  # [1, 2, 3].map{|i| i.to_s}
  def to_proc
    Proc.new {|obj, *args| obj.send(self, *args)}
  end
  
  # Concatenates a path
  def /(o)
    (self == :local) ? '/' + o.to_s : self.to_s + '/' + o.to_s
  end
end

