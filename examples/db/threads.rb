require File.join(File.dirname(__FILE__), '../../lib/serverside')

DB = Postgres::Database.new

$atts = DB[:node_attributes]

$atts.delete

$x = 5000

def do_insert(value)
  Thread.new do
    $x.times do
      $atts.insert(:node_id => rand(1000), :kind => rand(1000), :value => value)
    end
  end
end

t1 = Time.now
thread1 = do_insert(1)
thread2 = do_insert(2)
thread1.join
thread2.join
t2 = Time.now
elapsed = t2 - t1
puts "Inserts took #{elapsed} seconds (#{$x*2/elapsed} rows/s)"

puts "table now contains #{$atts.count} records."

puts "thread1 records: #{$atts.filter(:value => 1).count}"
puts "thread2 records: #{$atts.filter(:value => 2).count}"
