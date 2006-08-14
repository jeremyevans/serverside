module ServerSide
end

path = File.join(File.dirname(__FILE__), 'serverside')
Dir.foreach(path) {|fn| require File.join(path, fn) if fn =~ /\.rb$/}
