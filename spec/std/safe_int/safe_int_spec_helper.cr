require "spec"

macro run_op_tests(t, u, tests, op, raw_op)
  {{tests}}.each do |l, r, ok|
    lhs = {{t}}.new!(l)
    rhs = {{u}}.new!(r)

    it "test #{lhs} : #{{{t}}} + #{rhs} : #{{{u}}}" do
      begin
        if ok
          (lhs.{{op.id}} rhs).should eq(lhs {{raw_op.id}} rhs)
        else
          expect_raises(OverflowError) { lhs.{{op.id}} rhs }
        end
      rescue e : Spec::AssertionFailed
        raise Spec::AssertionFailed.new("#{e.message}: #{lhs} #{{{op}}} #{rhs}", e.file, e.line)
      end
    end
  end
end

def run_add_tests(t, u, tests)
  describe "add" do
    run_op_tests t, u, tests, :safe_add, :&+
  end
end
