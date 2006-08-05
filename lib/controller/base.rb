module Controller
  class Base
    def process(req)
      puts self.class
    end
  end
end