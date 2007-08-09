# ServerSide is a web framework that make it easy to create custom light-weight
# web applications. It contains the following functionalities:
# 1. A fast multithreaded HTTP server with support for persistent connections
# and streaming.
# 2. A static file handler.
# 3. A daemon for controlling a server or a cluster of servers.
# 4. A simple script for serving files or applications easily.
# 5. A simple controller-view system for processing requests.
module ServerSide
end

lib_dir = File.join(File.dirname(__FILE__), 'serverside')

require File.join(lib_dir, 'core_ext')
require File.join(lib_dir, 'http')
require File.join(lib_dir, 'daemon')
require File.join(lib_dir, 'cluster')
require File.join(lib_dir, 'log')
require File.join(lib_dir, 'template')
require File.join(lib_dir, 'js')
require File.join(lib_dir, 'xml')

