require "fiber"
require "spin_lock"

abstract class Channel(T)
  module SelectAction
    abstract def ready?
    abstract def execute
    abstract def wait
    abstract def unwait
  end

  class ClosedError < Exception
    def initialize(msg = "Channel is closed")
      super(msg)
    end
  end

  def initialize
    @closed = false
    @senders = Deque(Fiber).new
    @receivers = Deque(Fiber).new
  end

  def self.new : Unbuffered(T)
    Unbuffered(T).new
  end

  def self.new(capacity) : Buffered(T)
    Buffered(T).new(capacity)
  end

  def close
    @closed = true
    Crystal::Scheduler.enqueue @senders
    @senders.clear
    Crystal::Scheduler.enqueue @receivers
    @receivers.clear
    nil
  end

  def closed?
    @closed
  end

  def receive
    receive_impl { raise ClosedError.new }
  end

  def receive?
    receive_impl { return nil }
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  def pretty_print(pp)
    pp.text inspect
  end

  protected def wait_for_receive
    @receivers << Fiber.current
  end

  protected def unwait_for_receive
    @receivers.delete Fiber.current
  end

  protected def wait_for_send
    @senders << Fiber.current
  end

  protected def unwait_for_send
    @senders.delete Fiber.current
  end

  protected def raise_if_closed
    raise ClosedError.new if @closed
  end

  def self.receive_first(*channels)
    receive_first channels
  end

  def self.receive_first(channels : Tuple | Array)
    self.select(channels.map(&.receive_select_action))[1]
  end

  def self.send_first(value, *channels)
    send_first value, channels
  end

  def self.send_first(value, channels : Tuple | Array)
    self.select(channels.map(&.send_select_action(value)))
    nil
  end

  def self.select(*ops : SelectAction)
    self.select ops
  end

  def self.select(ops : Tuple | Array, has_else = false)
    loop do
      ops.each_with_index do |op, index|
        if op.ready?
          result = op.execute
          return index, result
        end
      end

      if has_else
        return ops.size, nil
      end

      ops.each &.wait
      Crystal::Scheduler.reschedule
      ops.each &.unwait
    end
  end

  # :nodoc:
  def send_select_action(value : T)
    SendAction.new(self, value)
  end

  # :nodoc:
  def receive_select_action
    ReceiveAction.new(self)
  end

  # :nodoc:
  struct ReceiveAction(C)
    include SelectAction

    def initialize(@channel : C)
    end

    def ready?
      !@channel.empty?
    end

    def execute
      @channel.receive
    end

    def wait
      @channel.wait_for_receive
    end

    def unwait
      @channel.unwait_for_receive
    end
  end

  # :nodoc:
  struct SendAction(C, T)
    include SelectAction

    def initialize(@channel : C, @value : T)
    end

    def ready?
      !@channel.full?
    end

    def execute
      @channel.send(@value)
    end

    def wait
      @channel.wait_for_send
    end

    def unwait
      @channel.unwait_for_send
    end
  end
end

class Channel::Buffered(T) < Channel(T)
  {% if flag?(:preview_mt) %}
    @lock = SpinLock.new
  {% else %}
    @lock = NullLock.new
  {% end %}

  def initialize(@capacity = 32)
    @queue = Deque(T).new(@capacity)
    super()
  end

  def send(value : T)
    @lock.sync do
      while full?
        raise_if_closed
        @senders << Fiber.current
        @lock.unsync do
          Crystal::Scheduler.reschedule
        end
      end

      raise_if_closed

      @queue << value
      if receiver = @receivers.shift?
        receiver.restore
      end
    end

    self
  end

  private def receive_impl
    @lock.sync do
      while empty?
        yield if @closed
        @receivers << Fiber.current
        @lock.unsync do
          Crystal::Scheduler.reschedule
        end
      end

      @queue.shift.tap do
        if sender = @senders.shift?
          sender.restore
        end
      end
    end
  end

  def full?
    @queue.size >= @capacity
  end

  def empty?
    @queue.empty?
  end
end

{% if !flag?(:preview_mt) %}
struct NullLock
  def sync
    yield
  end

  def unsync
    yield
  end
end
{% end %}

class Channel::Unbuffered(T) < Channel(T)
  @sender : Fiber?
  {% if flag?(:preview_mt) %}
    @lock = SpinLock.new
  {% else %}
    @lock = NullLock.new
  {% end %}

  def initialize
    @has_value = false
    @value = uninitialized T
    super
  end

  def send(value : T)
    receiver = nil

    @lock.sync do
      while @has_value
        raise_if_closed
        @senders << Fiber.current
        @lock.unsync do
          Crystal::Scheduler.reschedule
        end
      end

      raise_if_closed

      @value = value
      @has_value = true
      receiver = @receivers.shift?

      if !receiver
        @sender = Fiber.current
      end
    end

    if receiver
      receiver.restore
    else
      Crystal::Scheduler.reschedule
    end
  end

  private def receive_impl
    @lock.sync do
      until @has_value
        yield if @closed
        @receivers << Fiber.current
        if sender = @senders.shift?
          @lock.unsync do
            sender.restore
            Crystal::Scheduler.reschedule
          end
        else
          @lock.unsync do
            Crystal::Scheduler.reschedule
          end
        end
      end

      # At this point the channel might be closed already
      # but still the value is returned because the receiver
      # was scheduled by the sender before the channel was closed

      if sender = @sender
        sender.restore
      end

      if sender = @senders.shift?
        sender.restore
      end

      @has_value = false
      @sender = nil
      @value
    end
  end

  def empty?
    !@has_value && @senders.empty?
  end

  def full?
    @has_value || @receivers.empty?
  end

  def close
    super
    if sender = @sender
      Crystal::Scheduler.enqueue sender
      @sender = nil
    end
  end
end
