# ServerSide contains a number of modules that make it easy to create custom
# HTTP servers. It contains the following functionalities:
# 1. A fast multithreaded HTTP server (yes, faster than Mongrel.)
# 2. A simple controller-view system for processing HTTP requests.
# 3. A static file handler.
# 4. A daemon for controlling a server or a cluster of servers.
# 5. A nice script for serving files or applications easily.
module ServerSide
end

path = File.join(File.dirname(__FILE__), 'serverside')
Dir.foreach(path) {|fn| require File.join(path, fn) if fn =~ /\.rb$/}
