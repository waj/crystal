require "./zone_channel"

THREADS = 4

ch = ZoneChannel(Int32).new

THREADS.times do |i|
  Thread.new do
    loop do
      # ch.receive
      LibC.printf("%i - %i\n", i, ch.receive)
    end
  end
end

(0..).each do |i|
  ch.send i
end
