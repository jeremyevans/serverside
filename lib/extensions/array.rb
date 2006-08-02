# Array extension methods.
class Array
  alias_method :orig_map, :map
  
  # Override map to allow shortcuts like [1, 2, 3].map(:to_s)
  def map(*args, &block)
    selector = args.empty? ? nil : args.shift
    if (selector.class == Symbol) && block.nil?
      orig_map {|i| i.send(selector, *args)}
    else
      orig_map(*args, &block)
    end
  end
  
  # Iterates over the array and returns the first non-nil result of the
  # supplied block.
  def pluck_first(&block)
    begin
      r = nil
      each {|i| r = block.call(i); raise if r}
      nil
    rescue
      r
    end
  end
end