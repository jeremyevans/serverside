module ServerSide
  class Database
    attr_reader :conn
  
    def initialize(opts = {})
      @opts = opts
      @conn = make_connection
    end

    # Some convenience methods
    
    # Returns a new dataset with the from method invoked.
    def from(*args); query.from(*args); end
    
    # Returns a new dataset with the select method invoked.
    def select(*args); query.select(*args); end

    # returns a new dataset with the from method invoked. For example,
    #
    #   db[:posts].each {|p| puts p[:title]}
    def [](table)
      query.from(table)
    end
  end
end
