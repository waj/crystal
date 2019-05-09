# $ ../bin/crystal run -D preview_mt --release int128.cr -- 4 100000
THREADS = ARGV.fetch(0, "4").to_i
LOOPS   = ARGV.fetch(1, "10000000").to_i

require "./zone_channel"

pp! THREADS
pp! LOOPS

VAL_0 = UInt128::MIN
VAL_1 = UInt128::MAX

pp! VAL_0
pp! VAL_1

a = VAL_0

consistent_values = ->{
  z = {% if flag?(:atomic) %}
      Atomic::Ops.load(pointerof(a), :unordered, true)
      {% else %}
      a
      {% end %}
  if z == VAL_0 || z == VAL_1
    return {true, z}
  else
    return {false, z}
  end
}

set_all_to = ->(v : UInt128) {
  {% if flag?(:atomic) %}
  Atomic::Ops.store(pointerof(a), v, :unordered, true)
  {% else %}
  a = v
  {% end %}
}

done = ZoneChannel(Bool).new
finish_check = false

THREADS.times do |t|
  Thread.new do
    done.to_unsafe_zone

    LOOPS.times do
      set_all_to.call(t % 2 == 0 ? VAL_0 : VAL_1)
    end

    done.send(true)
  end
end

Thread.new do
  while finish_check == false
    r, v = consistent_values.call
    if r == false
      LibC.printf("WARNING values are not consistent #{v}\n")
      exit 1
    end
  end
  exit 0
end

Thread.new do
  loop do
    LibC.printf("a: #{a}\n")
    sleep 0.1
  end
end

THREADS.times do
  done.receive
end

finish_check = true
LibC.printf("OK values are consistent #{a}\n")
