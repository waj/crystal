require "./codegen"

class Crystal::CodeGenVisitor
  enum IntZone
    # unsigned-unsigned
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
      # unsigned-unsigned
      return UintLT32_UintLT32 if is_both_unsigned(t1, t2) && is_both_lt32bit(t1, t2)
      return Uint32_UintLT64 if is_both_unsigned(t1, t2) && is_32bit(t1) && is_lt64bit(t2)
      return UintLT32_Uint32 if is_both_unsigned(t1, t2) && is_lt32bit(t1) && is_32bit(t2)
      return Uint64_Uint if is_both_unsigned(t1, t2) && is_64bit(t1)
      return UintLT64_Uint64 if is_both_unsigned(t1, t2) && is_lt64bit(t1) && is_64bit(t2)
      # unsigned-signed
      return UintLT32_IntLT32 if t1.unsigned? && t2.signed? && is_both_lt32bit(t1, t2)
      return Uint32_IntLT64 if t1.kind == :u32 && t2.signed? && is_lt64bit(t2)
      return UintLT32_Int32 if t1.unsigned? && is_lt32bit(t1) && t2.kind == :i32
      # signed-signed
      return IntLT32_IntLT32 if is_both_signed(t1, t2) && is_both_lt32bit(t1, t2)
      return Int32_IntLT64 if is_both_signed(t1, t2) && is_32bit(t1) && is_lt64bit(t2)
      return IntLT32_Int32 if is_both_signed(t1, t2) && is_lt32bit(t1) && is_32bit(t2)
      # signed-unsigned
      return IntLT32_UintLT32 if t1.signed? && t2.unsigned? && is_both_lt32bit(t1, t2)

      raise "Unsuported zone: #{t1} #{t2}"
    end

    def self.is_both_unsigned(t1, t2)
      t1.unsigned? && t2.unsigned?
    end

    def self.is_both_signed(t1, t2)
      t1.signed? && t2.signed?
    end

    def self.is_both_lt32bit(t1, t2)
      t1.bytes < 4 && t2.bytes < 4
    end

    def self.is_32bit(t)
      t.bytes == 4
    end

    def self.is_lt32bit(t)
      t.bytes < 4
    end

    def self.is_lt64bit(t)
      t.bytes < 8
    end

    def self.is_64bit(t)
      t.bytes == 8
    end
  end

  def codegen_safe_int_add(t1, t2, p1, p2)
    case IntZone.for(t1, t2)
    # unsigned-unsigned
    when IntZone::UintLT32_UintLT32 then add_cast_int_check_max(t1, t2, p1, p2)
    when IntZone::Uint32_UintLT64   then add_cast_uint_check_overflow(t1, t2, p1, p2)
    when IntZone::UintLT32_Uint32   then add_cast_uint_check_overflow_max(t1, t2, p1, p2)
    when IntZone::Uint64_Uint       then add_cast_uint64_check_overflow(t1, t2, p1, p2)
    when IntZone::UintLT64_Uint64   then add_cast_uint64_check_overflow_max(t1, t2, p1, p2)
      # unsigned-signed
    when IntZone::UintLT32_IntLT32 then add_cast_int_check_safe_int_min_max(t1, t2, p1, p2)
    when IntZone::Uint32_IntLT64   then add_cast_int64_check_safe_int_min_max(t1, t2, p1, p2)
    when IntZone::UintLT32_Int32   then add_cast_int64_check_safe_int_min_max(t1, t2, p1, p2)
      # signed-signed
    when IntZone::IntLT32_IntLT32 then add_cast_int_check_safe_int_min_max(t1, t2, p1, p2)
    when IntZone::Int32_IntLT64   then add_cast_int64_check_safe_int_min_max(t1, t2, p1, p2)
    when IntZone::IntLT32_Int32   then add_cast_int64_check_safe_int_min_max(t1, t2, p1, p2)
      # signed-unsigned
    when IntZone::IntLT32_UintLT32 then add_cast_int_check_max(t1, t2, p1, p2)
    else                                raise "Unsuported zone for add: #{t1} #{t2}"
    end
  end

  def add_cast_int_check_max(t1, t2, p1, p2)
    ep1 = extend_int(t1, @program.int32, p1)
    ep2 = extend_int(t2, @program.int32, p2)
    tmp = builder.add(ep1, ep2)

    _, max_value = t1.range
    overflow = codegen_binary_op_gt @program.int32, @program.int32, tmp, int(max_value, @program.int32)
    codegen_raise_overflow_cond(overflow)
    trunc tmp, llvm_type(t1)
  end

  def add_cast_uint_check_overflow(t1, t2, p1, p2)
    ep1 = extend_int(t1, @program.uint32, p1)
    ep2 = extend_int(t2, @program.uint32, p2)
    tmp = builder.add(ep1, ep2)

    overflow = codegen_binary_op_lt @program.uint32, t1, tmp, p1
    codegen_raise_overflow_cond(overflow)
    trunc tmp, llvm_type(t1)
  end

  def add_cast_uint_check_overflow_max(t1, t2, p1, p2)
    ep1 = extend_int(t1, @program.uint32, p1)
    ep2 = extend_int(t2, @program.uint32, p2)
    tmp = builder.add(ep1, ep2)

    _, max_value = t1.range
    overflow = or(
      codegen_binary_op_lt(@program.uint32, t1, tmp, p1),
      codegen_binary_op_gt(@program.uint32, t1, tmp, int(max_value, t1))
    )
    codegen_raise_overflow_cond(overflow)
    trunc tmp, llvm_type(t1)
  end

  def add_cast_uint64_check_overflow(t1, t2, p1, p2)
    ep1 = extend_int(t1, @program.uint64, p1)
    ep2 = extend_int(t2, @program.uint64, p2)
    tmp = builder.add(ep1, ep2)

    overflow = codegen_binary_op_lt @program.uint64, t1, tmp, p1
    codegen_raise_overflow_cond(overflow)
    trunc tmp, llvm_type(t1)
  end

  def add_cast_uint64_check_overflow_max(t1, t2, p1, p2)
    ep1 = extend_int(t1, @program.uint64, p1)
    ep2 = extend_int(t2, @program.uint64, p2)
    tmp = builder.add(ep1, ep2)

    _, max_value = t1.range
    overflow = or(
      codegen_binary_op_lt(@program.uint64, t1, tmp, p1),
      codegen_binary_op_gt(@program.uint64, t1, tmp, int(max_value, t1))
    )
    codegen_raise_overflow_cond(overflow)
    trunc tmp, llvm_type(t1)
  end

  def add_cast_int_check_safe_int_min_max(t1, t2, p1, p2)
    ep1 = extend_int(t1, @program.int32, p1)
    ep2 = extend_int(t2, @program.int32, p2)
    tmp = builder.add(ep1, ep2)

    min_value, max_value = t1.range
    overflow = or(
      codegen_binary_op_lt(@program.int32, t1, tmp, int(min_value, t1)),
      codegen_binary_op_gt(@program.int32, t1, tmp, int(max_value, t1))
    )
    codegen_raise_overflow_cond(overflow)
    trunc tmp, llvm_type(t1)
  end

  def add_cast_int64_check_safe_int_min_max(t1, t2, p1, p2)
    ep1 = extend_int(t1, @program.int64, p1)
    ep2 = extend_int(t2, @program.int64, p2)
    tmp = builder.add(ep1, ep2)

    min_value, max_value = t1.range
    overflow = or(
      codegen_binary_op_lt(@program.int64, t1, tmp, int(min_value, t1)),
      codegen_binary_op_gt(@program.int64, t1, tmp, int(max_value, t1))
    )
    codegen_raise_overflow_cond(overflow)
    trunc tmp, llvm_type(t1)
  end
end
