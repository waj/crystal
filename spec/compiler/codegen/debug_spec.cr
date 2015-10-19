require "../../spec_helper"

describe "Code gen: exception" do
  it "runs" do
    debug %(
      (gdb) break foo
      (gdb) run
      (gdb) frame
      #0  foo () at spec:2
      (gdb) next
      (gdb) frame
      #0  foo () at spec:3
      (gdb) print x
      $1 = 1
      (gdb) next
      (gdb) print x
      $2 = 3
    ), %(
      def foo
        x = 1
        x = 3
      end

      foo
    )
  end
end


