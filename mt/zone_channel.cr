class ZoneChannel(T)
  @has_value = false
  @value = uninitialized T
  @lock = Thread::Mutex.new
  @value_available = Thread::ConditionVariable.new
  @space_available = Thread::ConditionVariable.new

  def send(value : T)
    @lock.synchronize do
      loop do
        if !@has_value
          @value = value
          @has_value = true
          @value_available.signal
          return
        else
          @space_available.wait(@lock)
        end
      end
    end
  end

  def receive : T
    @lock.synchronize do
      loop do
        if @has_value
          @has_value = false
          @space_available.signal
          return @value
        else
          @value_available.wait(@lock)
        end
      end
    end
  end
end
