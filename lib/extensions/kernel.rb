module Kernel
  def periodically(period, &block)
    Thread.new do
      last_time = Time.now
      loop do
        now = Time.now
        if now - last_time >= last_time
          last_time = now
          block.call rescue nil
        end
        sleep 0.1
      end
    end
  end
end
