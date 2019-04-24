require "http/server"
require "./zone_channel"

THREADS = ARGV.fetch(0, "4").to_i

class HTTP::Server
  # @zone_channel = ZoneChannel(Array(Socket::Server)).new # should be a thread-safe/readonly array
  # @zone_channel_done = ZoneChannel(Nil).new

  def listen
    raise "Can't re-start closed server" if closed?
    raise "Can't start server with no sockets to listen to, use HTTP::Server#bind first" if @sockets.empty?
    raise "Can't start running server" if listening?

    THREADS.times do |t|
      Thread.new do
        # @zone_channel.to_unsafe_zone
        # @zone_channel_done.to_unsafe_zone

        # sockets = @zone_channel.receive

        done = Channel(Nil).new

        @sockets.each do |socket|
          socket = socket.to_unsafe_zone if socket.responds_to?(:to_unsafe_zone)

          spawn do
            until self.closed?
              io = begin
                socket.accept?
              rescue e
                handle_exception(e)
                nil
              end

              if io
                LibC.printf("handle by %i\n", t)
                _io = io
                spawn handle_client(_io)
              end
            end
          ensure
            done.send nil
          end
        end

        @sockets.size.times { done.receive }
        # @zone_channel_done.send nil
      end
    end

    @listening = true

    # THREADS.times { @zone_channel.send @sockets }
    # THREADS.times { @zone_channel_done.receive }
    sleep
  end
end

server = HTTP::Server.new do |context|
  context.response.content_type = "text/plain"
  context.response.print "Hello world!"
end

address = server.bind_tcp 8080
puts "Listening on http://#{address}"
server.listen
