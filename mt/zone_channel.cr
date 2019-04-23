class ZoneChannel(T)
  @has_value = false
  @value = uninitialized T
  @lock = Thread::Mutex.new
  # @value_available = Thread::ConditionVariable.new
  @space_available = Thread::ConditionVariable.new

  @value_reader_per_thread = Hash(Thread, IO::FileDescriptor).new

  def initialize
    @value_reader, @value_writer = IO.pipe
    @value_reader_per_thread[Thread.current] = @value_reader
  end

  def to_unsafe_zone
    @value_reader_per_thread[Thread.current] = IO::FileDescriptor.new(@value_reader.fd, false)

    self
  end

  def send(value : T)
    @lock.synchronize do
      loop do
        if !@has_value
          @value = value
          @has_value = true
          # @value_available.signal
          @value_writer.write_byte 0
          return
        else
          @space_available.wait(@lock)
        end
      end
    end
  end

  def receive : T
    loop do
      @value_reader_per_thread[Thread.current].read_fully(Bytes.new(1))

      @lock.synchronize do
        if @has_value
          @has_value = false
          @space_available.signal
          return @value
        end
      end
    end
  end
end
