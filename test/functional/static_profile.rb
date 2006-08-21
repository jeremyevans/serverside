require 'rubygems'
require 'serverside'
require 'fileutils'

FileUtils.cd(File.dirname(__FILE__))

pid = fork do
  trap('TERM') {exit}
  require 'profile'
  ServerSide::Server.new('0.0.0.0', 8000, ServerSide::Connection::Static)
end

puts "Please wait..."
`ab -n 1000 http://localhost:8000/#{File.basename(__FILE__)}`
puts
Process.kill('TERM', pid)
puts
