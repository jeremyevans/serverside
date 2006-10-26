require File.dirname(__FILE__) + '/../test_helper'
require 'fileutils'

FileUtils.cd(File.dirname(__FILE__))

trap('INT') {exit}

ServerSide::Router.route(:path => '^/static/:path') {serve_static('.'/@parameters[:path])}
ServerSide::Router.route(:path => '/hello$') {send_response(200, 'text', 'Hello world!')}
ServerSide::Router.route(:path => '/xml') do
  redirect('http://feeds.feedburner.com/RobbyOnRails')
end

ServerSide::HTTP::Server.new('0.0.0.0', 4401, ServerSide::Router).start
