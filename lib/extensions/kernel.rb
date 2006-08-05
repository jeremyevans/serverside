module Kernel
  def periodically(period, &block)
    Thread.new do
      last_time = Time.now
      loop do
        now = Time.now
        if now - last_time >= period
          last_time = now
          block.call rescue nil
        else
          sleep 0.001
        end
      end
    end
  end
end
