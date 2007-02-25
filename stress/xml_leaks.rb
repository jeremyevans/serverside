require 'rubygems'
require File.join(File.dirname(__FILE__), '../lib/serverside')

trap('INT') {exit}

def test
  1000.times do
    xml = ServerSide::XML.new(:reality) do |x|
      x.result 'OK'
      x.node do
        x.id 1
        x.path '/'
        x.quality 3
        x.stamp Time.now
        x.value rand(1000)
        x.datatype 3
      end
    end
    Thread.exclusive {puts xml.to_s}
  end
end

while true
  sleep 0.1
  if Thread.list.size < 15
    Thread.new {test}
  end
end
