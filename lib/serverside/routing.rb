module ServerSide
  module Connection
    # The Router class defines a kind of connection that can route requests
    # to different handlers based on rules that can be specified either by
    # lambdas or by hashes containing keys corresponding to patterns.
    class Router < Base
      # Returns true if routes were defined.
      def self.has_routes?
        @@rules && !@@rules.empty? rescue false
      end
      
      # Adds a routing rule. The normalized rule is a hash containing keys (acting
      # as instance variable names) with patterns as values. If the rule is not a
      # hash, it is normalized into a pattern checked against the request path.
      # Pattern values can also be arrays, in any array member is checked as a pattern.
      def self.route(rule, &block)
        @@rules ||= []
        rule = {:path => rule} unless (Hash === rule) || (Proc === rule)
        @@rules.unshift [rule, block]
        compile_rules
      end
      
      # Compiles all rules into a respond method that is invoked when a request
      # is received.
      def self.compile_rules
        @@rules ||= []
        code = @@rules.inject('lambda {') {|m, r| m << rule_to_statement(r[0], r[1])}
        code << 'default_handler}'
        define_method(:respond, &eval(code))
      end
      
      # Converts a rule into an if statement. All keys in the rule are matched
      # against their respective values.
      def self.rule_to_statement(rule, block)
        proc_tag = define_proc(&block)
        if Proc === rule
          cond = define_proc(&rule).to_s
        else
          cond = rule.to_a.map {|kv|
            if Array === kv[1]
              '(' + kv[1].map {|v| condition_part(kv[0], v)}.join('||') + ')'
            else
              condition_part(kv[0], kv[1])
            end
          }.join('&&')
        end
        "return #{proc_tag} if #{cond}\n"
      end

      # Pattern for finding parameters inside patterns. Parameters are parts of the
      # pattern, which the routing pre-processor turns into sub-regexp that are
      # used to extract parameter values from the pattern.
      #
      # For example, matching '/controller/show' against '/controller/:action' will
      # give us @parameters[:action] #=> "show"
      ParamRegexp = /(?::([a-z]+))/

      # Returns the condition part for the key and value specified. The key is the
      # name of an instance variable and the value is a pattern to match against.
      # If the pattern contains parameters (for example, /controller/:action,) the
      # method creates a lambda for extracting the parameter values.
      def self.condition_part(key, value)
        p_parse, p_count = '', 0
        while (String === value) && (value =~ ParamRegexp)
          value = value.dup
          p_name = $1
          p_count += 1
          value.sub!(ParamRegexp, '(.+)')
          p_parse << "@parameters[:#{p_name}] = $#{p_count}\n"
        end
        cond = "(@#{key} =~ #{cache_constant(Regexp.new(value))})"
        if p_count == 0
          cond
        else
          tag = define_proc(&eval(
            "lambda {if #{cond}\n#{p_parse}true\nelse\nfalse\nend}"))
          "(#{tag})"
        end
      end

      # Converts a proc into a method, returning the method's name (as a symbol)
      def self.define_proc(&block)
        tag = block.proc_tag
        define_method(tag.to_sym, &block) unless instance_methods.include?(tag)
        tag.to_sym
      end

      # Converts a value into a local constant and freezes it. Returns the 
      # constant's tag name
      def self.cache_constant(value)
        tag = value.const_tag
        class_eval "#{tag} = #{value.inspect}.freeze" rescue nil
        tag
      end

      # Sets the default handler for incoming requests.
      def self.route_default(&block)
        define_method(:default_handler, &block)
        compile_rules
      end

      def unhandled
        send_response(403, 'text', 'No handler found.')
      end

      alias_method :default_handler, :unhandled
    end
  end
  
  # Adds a routing rule. This is a convenience method.
  def self.route(rule, &block)
    Connection::Router.route(rule, &block)
  end
  
  # Sets the default request handler. This is a convenience method.
  def self.route_default(&block)
    Connection::Router.route_default(&block)
  end
end
