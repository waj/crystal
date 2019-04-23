require "http/server"
require "./zone_channel"

THREADS = ARGV.fetch(0, "4").to_i

class HTTP::Server
  @zone_channel = ZoneChannel(IO).new

  def listen
    raise "Can't re-start closed server" if closed?
    raise "Can't start server with no sockets to listen to, use HTTP::Server#bind first" if @sockets.empty?
    raise "Can't start running server" if listening?

    THREADS.times do |t|
      Thread.new do
        @zone_channel.to_unsafe_zone

        # how to ensure `self` is safe to go cross-zone
        until self.closed?
          LibC.printf("handle %i\n", t)

          io = @zone_channel.receive # this blocks the entire thread
          io.clear_events! if io.responds_to?(:clear_events!)

          spawn handle_client(io)
        end
      end
    end

    @listening = true
    done = Channel(Nil).new

    @sockets.each do |socket|
      spawn do
        until closed?
          io = begin
            socket.accept?
          rescue e
            handle_exception(e)
            nil
          end

          if io
            LibC.printf("sent request\n")
            @zone_channel.send io
          end
        end
      ensure
        done.send nil
      end
    end

    @sockets.size.times { done.receive }
  end
end

server = HTTP::Server.new do |context|
  LibC.printf("init\n")
  context.response.content_type = "text/plain"
  context.response.print "Hello world!"
  LibC.printf("finish\n")
end

address = server.bind_tcp 8080
puts "Listening on http://#{address}"
server.listen
