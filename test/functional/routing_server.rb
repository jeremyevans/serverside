require File.dirname(__FILE__) + '/../test_helper'
require 'fileutils'

FileUtils.cd(File.dirname(__FILE__))

trap('TERM') {exit}

ServerSide::route(:path => '^/static/:path') {serve_static('.'/@parameters[:path])}
ServerSide::route(:path => '/hello$') {send_response(200, 'text', 'Hello world!')}
ServerSide.route(:path => '/xml/:flavor/feed.xml') do
  redirect('http://feeds.feedburner.com/RobbyOnRails')
end

ServerSide::HTTP::Server.new('0.0.0.0', 8000, ServerSide::Router)
