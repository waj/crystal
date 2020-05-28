require "./codegen"

class Crystal::CodeGenVisitor
  enum IntZone
    # unsigned-unsigned zone
    UintLT32_UintLT32
    Uint32_UintLT64
    UintLT32_Uint32
    Uint64_Uint
    UintLT64_Uint64
    # unsigned-signed
    UintLT32_IntLT32
    Uint32_IntLT64
    UintLT32_Int32
    Uint64_Int
    UintLT64_Int64
    Uint64_Int64
    # signed-signed
    IntLT32_IntLT32
    Int32_IntLT64
    IntLT32_Int32
    Int64_Int64
    Int64_Int
    IntLT64_Int64
    # signed-unsigned
    IntLT32_UintLT32
    Int32_UintLT32
    IntLT64_Uint32
    Int64_UintLT64
    Int_Uint64
    Int64_Uint64

    def self.for(t1, t2)
      return UintLT32_UintLT32 if is_both_unsigned(t1, t2) && is_both_lt32bit(t1, t2)
      return IntLT32_UintLT32 if t1.signed? && t2.unsigned? && is_both_lt32bit(t1, t2)
      raise "Unsuported zone: #{t1} #{t2}"
    end

    def self.is_both_unsigned(t1, t2)
      t1.unsigned? && t2.unsigned?
    end

    def self.is_both_lt32bit(t1, t2)
      t1.bytes < 4 && t2.bytes < 4
    end
  end

  def codegen_safe_int_add(t1, t2, p1, p2)
    case IntZone.for(t1, t2)
    when IntZone::UintLT32_UintLT32 then add_cast_int_check_max(t1, t2, p1, p2)
    when IntZone::IntLT32_UintLT32  then add_cast_int_check_max(t1, t2, p1, p2)
    else                                 raise "Unsuported zone for add: #{t1} #{t2}"
    end
  end

  def add_cast_int_check_max(t1, t2, p1, p2)
    p1 = extend_int(t1, @program.int32, p1)
    p2 = extend_int(t2, @program.int32, p2)

    tmp = builder.add(p1, p2)
    _, max_value = t1.range
    overflow = codegen_binary_op_gt @program.int32, @program.int32, tmp, int(max_value, @program.int32)
    codegen_raise_overflow_cond(overflow)
    trunc tmp, llvm_type(t1)
  end
end
