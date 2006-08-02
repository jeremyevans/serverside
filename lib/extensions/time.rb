require 'time'

# Time extension methods.
class Time
  # Returns the current timestamp as a Float.
  def self.ticks
    now.to_f
  end
  
  # Returns the time a day from now.
  def next_day
    self + 1.day
  end
  
  # Returns the time a day before now.
  def prev_day
    self - 1.day
  end
  
  # Returns an array containing to Time objects
  def self.parse_range(value)
    if value.is_a? String
      delimited = value.split(',').map(:strip)
      return [parse_start(delimited[0]), parse_end(delimited[1])] if
        delimited.size == 2
    end
    
    n = now
    case value.to_sym
    when :today, :yesterday
      [parse_start(value), parse_end(value)]
    when :thisweek
      [n.beginning_of_week, n]
    when :thismonth
      [n.beginning_of_month, n]
    when :sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday
      t = parse_start(value)
      [t, t + 1.day]
    when :all
      [at(0), n]
    else
      if value == '1 minute'
        [n - 60, n]
      elsif value =~ /^(\d+) minutes$/
        [n - 60 * $1.to_f, n]
      elsif value == '1 hour'
        [n - 3600, n]
      elsif value =~ /^(\d+) hours$/
        [n - 3600 * $1.to_f, n]
      elsif value == '1 day'
        [n - 86400, n]
      elsif value =~ /^(\d+) days$/
        [n - 86400 * $1.to_f, n]
      elsif value == '1 week'
        [n - 86400 * 7, n]
      elsif value =~ /^(\d+) weeks$/
        [n - 86400 * 7 * $1.to_f, n]
      else
        nil
      end
    end
  end
  
  # Parses the start of a time range.
  def self.parse_start(value)
    sym = value.to_sym
    case sym
    when :today
      now.at_midnight
    when :yesterday
      (now - 1.day).at_midnight
    when :sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday
      last_weekday_at_midnight(sym)
    else
      parse value
    end
  end
  
  # Parses the end of a time range.
  def self.parse_end(value)
    sym = value.to_sym
    case sym
    when :today
      now.next_day.at_midnight - 1
    when :yesterday
      now.at_midnight - 1
    when :sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday
      last_weekday_at_midnight(sym)
    else
      parse value
    end
  end
  
  # Returns the time of the last specified weekday at midnight.
  def self.last_weekday_at_midnight(day)
    n = now
    ofs = parse_week_day(day) - n.wday
    if ofs <= 0
      (n + ofs.day).at_midnight
    else
      (n - (7 - ofs).day).at_midnight
    end
  end
  
  # Returns the week day number for the specified name.
  def self.parse_week_day(day)
    case day.to_sym
    when :sunday
      7
    when :monday
      1
    when :tuesday
      2
    when :wednesday
      3
    when :thursday
      4
    when :friday
      5
    when :saturday
      6
    else
      day
    end
  end
  
  # Formats the time stamp by checking if it occurs today. If it's today, then
  # only the time is formatted. Otherwise the date is included is well. 
  def smart_to_s(mode = :smart)
    if (Time.now.to_date != self.to_date) || (mode == :full)
      strftime "%Y-%m-%d %H:%M:%S"
    else
      strftime "%H:%M:%S"
    end
  end
  
  # Returns the time stamp in long format.
  def long_to_s(mode = :smart)
    strftime "%Y-%m-%d %H:%M:%S"
  end
  
  # Normalizes the time stamp by quantifying it to the specified resolution.
  def normalize(q)
    q ? Time.at((to_f / q).to_i * q) : self
  end
end
