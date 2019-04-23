THREADS = ARGV.fetch(0, "4").to_i
SIZE    = ARGV.fetch(1, "400").to_i
require "./zone_channel"

R = Random.new

A = Array(Array(Int32)).new(SIZE) { Array(Int32).new(SIZE) { R.rand(-100..100) } }
B = Array(Array(Int32)).new(SIZE) { Array(Int32).new(SIZE) { R.rand(-100..100) } }

def compute(i, j)
  res = 0
  SIZE.times do |k|
    res += A[i][k] * B[k][j]
  end
  res
end

# Single Thread
if THREADS == 1
  c = Array(Array(Int32)).new(SIZE) { |i| Array(Int32).new(SIZE) { |j| compute(i, j) } }
  puts c.size
else
  # Multi Thread
  c = Array(Array(Int32)).new(SIZE) { |i| Array(Int32).new(SIZE, 0) }

  request = ZoneChannel(Int32).new
  done = ZoneChannel(Bool).new

  THREADS.times do |w|
    Thread.new do
      loop do
        i = request.receive

        SIZE.times do |j|
          c[i][j] = compute(i, j)
        end

        done.send(true)
      end
    end
  end

  Thread.new do
    SIZE.times do |i|
      request.send(i)
    end
  end

  SIZE.times do
    done.receive
  end

  puts c.size
end
