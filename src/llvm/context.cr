class LLVM::Context
  def initialize(@unwrap)
  end

  def self.new
    new LibLLVM.create_context
  end

  def self.global
    new LibLLVM.get_global_context
  end

  def to_unsafe
    @unwrap
  end
end
