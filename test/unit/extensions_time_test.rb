require File.dirname(__FILE__) + '/../test_helper'

class ExtensionsTimeTest < Test::Unit::TestCase
  def test_ticks
    t = Time.ticks
    assert_instance_of Float, t
    sleep 0.4
    elapsed = Time.ticks - t
    assert (elapsed > 0.3) && (elapsed < 0.7)
  end
  
  def test_next_day
    t = Time.now
    n = t.next_day
    
    assert_equal 86400, n - t
    assert_equal 1, n.to_date - t.to_date
  end
  
  def test_prev_day
    t = Time.now
    p = t.prev_day
    
    assert_equal -86400, p - t
    assert_equal -1, p.to_date - t.to_date
  end
  
  def test_parse_range
    t1 = Time.now
    t2 = Time.now + 10
    r = Time.parse_range("#{t1}, #{t2}")
    assert_instance_of Array, r
    assert_equal 2, r.size
    assert_instance_of Time, r.first
    assert_instance_of Time, r.last
    assert_equal t1.to_i, r.first.to_i
    assert_equal t2.to_i, r.last.to_i
    
    assert_nil Time.parse_range('invalid')
    
    t = Time.now
    r = Time.parse_range('1 minute')
    assert_equal 60, r[1] - r[0]
    assert r[1] > t
    
    t = Time.now
    r = Time.parse_range('23 minutes')
    assert_equal 23 * 60, r[1] - r[0]
    assert r[1] > t
    
    t = Time.now
    r = Time.parse_range('1 hour')
    assert_equal 3600, r[1] - r[0]
    assert r[1] > t
    
    t = Time.now
    r = Time.parse_range('13 hours')
    assert_equal 13 * 3600, r[1] - r[0]
    assert r[1] > t

    
    t = Time.now
    r = Time.parse_range('1 day')
    assert_equal 86400, r[1] - r[0]
    assert r[1] > t
    
    t = Time.now
    r = Time.parse_range('3 days')
    assert_equal 3 * 86400, r[1] - r[0]
    assert r[1] > t
    
    t = Time.now
    r = Time.parse_range('1 week')
    assert_equal 7 * 86400, r[1] - r[0]
    assert r[1] > t
    
    t = Time.now
    r = Time.parse_range('3 weeks')
    assert_equal 3 * 7 * 86400, r[1] - r[0]
    assert r[1] > t
  end
  
  def test_parse_today
    t = Time.now
    r = Time.parse_range('today, today')
    assert_instance_of Array, r  
    assert_equal 2, r.size
    assert_equal t.to_date, r.first.to_date
    assert_equal t.at_midnight, r.first
    assert_equal t.to_date, r.last.to_date
    assert_equal t.next_day.at_midnight - 1, r.last
  end
  
  def test_parse_yesterday
    t = Time.now
    r = Time.parse_range('yesterday, today')
    assert_equal t.to_date - 1, r.first.to_date
    assert_equal t.prev_day.at_midnight, r.first
    assert_equal t.to_date, r.last.to_date
    assert_equal t.next_day.at_midnight - 1, r.last
  end
end
