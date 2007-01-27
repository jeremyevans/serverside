require File.join(File.dirname(__FILE__), '../lib/serverside')
require File.join(File.dirname(__FILE__), '../lib/serverside/db/postgres')

$db = Postgres::Database.new(:host => '127.0.0.1', :database => 'test')

def test(duration = 0.5)
  d = $db.from('foo')
  $db.transaction do
    row = d.first
    sleep duration
    Thread.exclusive {p row}
  end
rescue => e
  puts e.message
  puts e.backtrace.first
end

10.times {sleep 1;Thread.new {test(10)}}

while Thread.list.size > 1
  sleep 0.01
end
  
p $db.pool.size

__END__

1.times do
  Thread.new do
    while true
      sleep 0.01
      test
    end
  end
end

sleep 5

puts $db.pool.size