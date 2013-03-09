GC.disable
require 'bundler/setup'
require 'pry'
require 'pry-debugger'
require(File.expand_path("../../lib/crystal",  __FILE__))

RSpec.configure do |c|
  c.treat_symbols_as_metadata_keys_with_true_values = true
  c.filter_run_excluding :integration
end

include Crystal

# Escaped regexp
def regex(str)
  /#{Regexp.escape(str)}/
end

def assert_type(str, options = {}, &block)
  input = parse str
  mod = infer_type input, options
  expected_type = mod.instance_eval &block
  if input.is_a?(Expressions)
    input.last.type.should eq(expected_type)
  else
    input.type.should eq(expected_type)
  end
end

def permutate_primitive_types
  [['Int', ''], ['Long', 'L'], ['Float', '.0f'], ['Double', '.0']].repeated_permutation(2) do |p1, p2|
    type1, suffix1 = p1
    type2, suffix2 = p2
    yield type1, type2, suffix1, suffix2
  end
end

def primitive_operation_type(*types)
  return double if types.include?('Double')
  return float if types.include?('Float')
  return long if types.include?('Long')
  return int if types.include?('Int')
end

def rw(name)
  %Q(
  def #{name}=(value)
    @#{name} = value
  end

  def #{name}
    @#{name}
  end
  )
end

# Extend some Ruby core classes to make it easier
# to create Crystal AST nodes.

class FalseClass
  def bool
    Crystal::BoolLiteral.new self
  end
end

class TrueClass
  def bool
    Crystal::BoolLiteral.new self
  end
end

class Fixnum
  def int
    Crystal::IntLiteral.new self
  end

  def long
    Crystal::LongLiteral.new self
  end

  def float
    Crystal::FloatLiteral.new self.to_f
  end

  def double
    Crystal::DoubleLiteral.new self.to_f
  end
end

class Float
  def float
    Crystal::FloatLiteral.new self
  end

  def double
    Crystal::DoubleLiteral.new self
  end
end

class String
  def var
    Crystal::Var.new self
  end

  def arg
    Crystal::Arg.new self
  end

  def call(*args)
    Crystal::Call.new nil, self, args
  end

  def ident
    Crystal::Ident.new [self]
  end

  def instance_var
    Crystal::InstanceVar.new self
  end

  def string
    Crystal::StringLiteral.new self
  end

  def symbol
    Crystal::SymbolLiteral.new self
  end
end

class Array
  def ident
    Ident.new self
  end

  def array
    Crystal::ArrayLiteral.new self
  end

  def union
    UnionType.new(*self)
  end
end

class Crystal::Program
  def array_of(type = nil)
    types['Array'].clone.
      with_var('@length', int).
      with_var('@capacity', int).
      with_var('@buffer', PointerType.of(type))
  end
end

class Crystal::ObjectType
  def with_var(name, type)
    @instance_vars[name] = Var.new(name, type)
    self
  end

  def generic!
    @type_vars = []
    self
  end
end

class Crystal::PointerType
  def self.of(type)
    pointer = new
    pointer.var.type = type
    pointer
  end
end

class Crystal::ASTNode
  def not
    Call.new(self, :"!@")
  end
end