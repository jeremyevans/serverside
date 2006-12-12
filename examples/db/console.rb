require File.join(File.dirname(__FILE__), '../../lib/serverside')

DB = Postgres::Database.new(:database => 'sandbox')

dataset = DB.query

trap("INT") {exit}

def prompt
  print("> ")
  gets
end

def print_dataset(dataset)
  if dataset.result.cmdtuples > 0
    puts "%d affected rows." % dataset.result.cmdtuples
  else
    count = 0
    fields = dataset.fields
    return if fields.size == 0
    fields.each {|f| print "%-9.9s|" % f}; puts
    puts ("*" * fields.size * 10)
    dataset.result_each do |r|
      fields.each {|f| print "%-9.9s|" % r[f]}; puts
      count += 1
    end
    puts ("*" * fields.size * 10) if count > 0
    puts "%d records" % count
  end
end

while s = prompt
  break if s =~ /\.quit/i
  
  begin
    dataset.perform(s)
    results = []
    print_dataset(dataset)
  rescue => e
    puts e.message
  end
end

