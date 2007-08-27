require 'metaid'

module ServerSide
  class XML
    # blank slate
    instance_methods.each {|m|
      undef_method m unless (m =~ /^__|instance_eval|meta|respond_to/)}
  
    TAG_LEFT_OPEN = '<'.freeze
    TAG_LEFT_CLOSE = '</'.freeze
    TAG_RIGHT = '>'.freeze
  
    def __open_tag(tag, atts)
      @doc << TAG_LEFT_OPEN
      @doc << tag.to_s
      @doc << __fmt_atts(atts) if atts
      @doc << TAG_RIGHT
    end
  
    def __close_tag(tag)
      @doc << TAG_LEFT_CLOSE
      @doc << tag.to_s
      @doc << TAG_RIGHT
    end
  
    def __value(value)
      @doc << value.to_s.html_escape
    end
  
    INSTRUCT_LEFT = '<?xml'.freeze
    INSTRUCT_RIGHT = '?>'.freeze

    def __instruct(arg)
      @doc << INSTRUCT_LEFT
      @doc << __fmt_atts(arg)
      @doc << INSTRUCT_RIGHT
    end
  
    SPACE = ' '.freeze

    def __fmt_atts(atts)
      atts.inject('') {|m, i| m << " #{i[0]}=#{i[1].to_s.inspect}"}
    end
  
  
    def initialize(tag = nil, atts = nil, &block)
      @doc = ''
      __open_tag(tag, atts) if tag
      block.call(self) if block
      __close_tag(tag) if tag
    end
  
    def method_missing(tag, *args, &block)
      if block
        __open_tag(tag, args.first)
        block.call(self)
        __close_tag(tag)
      else
        value, atts = args.pop, args.pop
        subtags, atts = atts, nil if atts.is_a?(Array)
        if subtags
          __open_tag(tag, atts)
          subtags.each {|k| __send__(k, value[k])}
          __close_tag(tag)
        else
          __open_tag(tag, atts)
          __value(value)
          __close_tag(tag)
        end
      end
      self
    end

    def instruct!(atts = nil)
      __instruct(atts || {:version => "1.0", :encoding => "UTF-8"})
    end

    def to_s
      @doc
    end
    
    alias_method :inspect, :to_s
  end
end
