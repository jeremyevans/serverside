require 'rubygems'
require 'serverside'

module HelloWorldServer
  include ServerSide::HTTP::Server

  def handle(req)
    case req.path
    when '/'
      ServerSide::HTTP::Response.new(
        :body => 'Hello world'
      )
    when '/static'
      ServerSide::HTTP::Response.static(__FILE__)
    when '/stream'
      r = ServerSide::HTTP::Response.new(:content_type => 'text/html')
      r.stream(1, true) do |conn|
        conn.send_data("The time is #{Time.now}<br/>")
      end
      r
    end
  end
end

trap("INT") {EventMachine.stop}
puts "Serving on port 8000...."
EventMachine::run do
  EventMachine::start_server '0.0.0.0', 8000, HelloWorldServer
end