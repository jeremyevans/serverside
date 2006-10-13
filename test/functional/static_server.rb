require 'lib/serverside'

trap('INT') {exit}
include ServerSide
puts "Serving on port 8000..."
Router.route_default {serve_static('.'/@path)}
HTTP::Server.new('0.0.0.0', 8000, Router)
