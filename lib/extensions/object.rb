class Object
  def self.frozen(hash = {})
    unless const_defined?("Frozen")
      class_eval 'class Frozen; def self.const_missing(name); const_set(name, name.to_s.freeze); end; end'
    end
    hash.each {|k, v| class_eval "Frozen.const_set(k, v.freeze)"}
  end
end
