THREADS = 8
FIBERS  = 3

THREADS.times do |i|
  Thread.new do
    channels = FIBERS.times.map { Channel(Bool).new }.to_a
    fibers = (FIBERS - 1).times.map do |j|
      spawn do
        loop do
          # LibC.printf("%i - %i\n", i, j)
          channels[j].receive
          channels[j + 1].send(true)
        end
      end
    end.to_a

    loop do
      # LibC.printf("%i - %i\n", i, FIBERS - 1)
      channels.first.send(true)
      channels.last.receive
    end
  end
end

sleep
