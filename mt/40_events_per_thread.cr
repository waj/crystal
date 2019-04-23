THREADS = ARGV.fetch(0, "4").to_i
FIBERS  = ARGV.fetch(1, "4").to_i

THREADS.times do |t|
  Thread.new do
    FIBERS.times do |f|
      spawn do
        loop do
          LibC.printf("%i - %i\n", t, f)
          sleep 1
        end
      end
    end

    sleep
  end
end

sleep
