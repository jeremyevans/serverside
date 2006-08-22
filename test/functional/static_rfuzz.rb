# Simple script that hits a host port and URI with a bunch of connections
# and measures the timings.

require 'rubygems'
require 'rfuzz/client'
require 'rfuzz/stats'
include RFuzz

class StatsTracker

  def initialize
    @stats = {}
    @begins = {}
    @error_count = 0
  end

  def mark(event)
    @begins[event] = Time.now
  end

  def sample(event)
    @stats[event] ||= Stats.new(event.to_s)
    @stats[event].sample(Time.now - @begins[event])
  end

  def method_missing(event, *args)
    case args[0]
    when :begins
      mark(:request) if event == :connect
      mark(event)
    when :ends
      sample(:request) if event == :close
      sample(event)
    when :error
      @error_count += 1
    end
  end

  def to_s
    request = @stats[:request]
    @stats.delete :request
    "#{request}\n----\n#{@stats.values.join("\n")}\nErrors: #@error_count"
  end
end


if ARGV.length != 4
  STDERR.puts "usage:  ruby perftest.rb host port uri count"
  exit 1
end

host, port, uri, count = ARGV[0], ARGV[1], ARGV[2], ARGV[3].to_i

codes = {}
cl = HttpClient.new(host, port, :notifier => StatsTracker.new)
count.times do
  begin
    resp = cl.get(uri)
    code = resp.http_status.to_i
    codes[code] ||= 0
    codes[code] += 1
  rescue Object
  end
end

puts cl.notifier.to_s
puts "Status Codes: #{codes.inspect}"
