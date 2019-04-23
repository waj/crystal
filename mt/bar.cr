require "http/server"
require "./zone_channel"

THREADS = ARGV.fetch(0, "4").to_i

ch = ZoneChannel(Nil).new

Thread.new do
  loop do
    ch.receive

    spawn do
      loop do
        LibC.printf(".\n")
        sleep 1
      end
    end

    sleep 0
  end
end

loop do
  ch.send nil
  sleep 2
end
