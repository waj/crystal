class RWLock
  @writer = Atomic(Int32).new(0)
  @readers = Atomic(Int32).new(0)

  def read_lock
    loop do
      while @writer.get != 0
      end

      @readers.add(1)

      break if @writer.get == 0

      @readers.sub(1)
    end
  end

  def read_unlock
    @readers.sub(1)
  end

  def write_lock
    while @writer.swap(1) != 0
    end

    while @readers.get != 0
    end
  end

  def write_unlock
    @writer.lazy_set(0)
  end
end
