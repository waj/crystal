require "big"
require "spec"

struct Int
  def self.test_cases(values)
    values.map { |v| self.new!(v) }
  end
end

struct Int8
  TEST_CASES = test_cases [0x00, 0x01, 0x02, 0x7e, 0x7f, 0x80, 0x81, 0xfe, 0xff]
end

struct UInt8
  TEST_CASES = test_cases [0x00, 0x01, 0x02, 0x7e, 0x7f, 0x80, 0x81, 0xfe, 0xff]
end

struct UInt16
  TEST_CASES = test_cases [0x0000, 0x0001, 0x0002, 0x7ffe, 0x7fff, 0x8000, 0x8001, 0xfffe, 0xffff]
end

struct UInt32
  TEST_CASES = test_cases [0x00000000, 0x00000001, 0x00000002, 0x7ffffffe, 0x7fffffff, 0x80000000, 0x80000001, 0xfffffffe, 0xffffffff]
end

struct UInt64
  TEST_CASES = test_cases [0x0000000000000000, 0x0000000000000001, 0x0000000000000002, 0x000000007ffffffe, 0x000000007fffffff, 0x0000000080000000, 0x0000000080000001, 0x00000000fffffffe, 0x00000000ffffffff, 0x0000000100000000, 0x0000000200000000, 0x7ffffffffffffffe, 0x7fffffffffffffff, 0x8000000000000000, 0x8000000000000001, 0xfffffffffffffffe, 0xffffffffffffffff]
end

struct Int64
  TEST_CASES = test_cases [0x0000000000000000, 0x0000000000000001, 0x0000000000000002, 0x000000007ffffffe, 0x000000007fffffff, 0x0000000080000000, 0x0000000080000001, 0x00000000fffffffe, 0x00000000ffffffff, 0x0000000100000000, 0x0000000200000000, 0x7ffffffffffffffe, 0x7fffffffffffffff, 0x8000000000000000, 0x8000000000000001, 0xfffffffffffffffe, 0xffffffffffffffff]
end

macro run_op_tests(t, u, big_op, checked_op, unchecked_op)
  {{t}}::TEST_CASES.each do |lhs|
    {{u}}::TEST_CASES.each do |rhs|
      result = lhs.to_big_i {{big_op.id}} rhs.to_big_i
      passes = {{t}}::MIN <= result <= {{t}}::MAX
      it "test #{lhs} : #{{{t}}} + #{rhs} : #{{{u}}}" do
        begin
          if passes
            lhs.{{checked_op.id}}(rhs).should eq(lhs.{{unchecked_op.id}}(rhs))
          else
            expect_raises(OverflowError) { lhs.{{checked_op.id}}(rhs) }
          end
        rescue e : Spec::AssertionFailed
          raise Spec::AssertionFailed.new("#{e.message}: #{lhs} #{{{checked_op}}} #{rhs}", e.file, e.line)
        end
      end
    end
  end
end

macro run_add_tests(t, u)
  run_op_tests {{t}}, {{u}}, :+, :safe_add, :&+
end

describe "add" do
  run_add_tests Int8, UInt8
  run_add_tests Int8, UInt16
  run_add_tests UInt8, UInt8
  run_add_tests UInt8, UInt16
  run_add_tests UInt32, UInt8
  run_add_tests UInt32, UInt16
  run_add_tests UInt32, UInt32
  run_add_tests UInt8, UInt32
  run_add_tests UInt16, UInt32
  run_add_tests UInt64, UInt8
  run_add_tests UInt64, UInt16
  run_add_tests UInt64, UInt32
  run_add_tests UInt64, UInt64
  run_add_tests UInt8, UInt64
  run_add_tests UInt16, UInt64
  run_add_tests UInt32, UInt64

  # run_add_tests UInt64, Int64
end
