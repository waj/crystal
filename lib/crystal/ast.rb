require_relative 'core_ext/module'
require_relative 'core_ext/string'

module Crystal
  class Visitor
    def visit_any(node)
    end
  end

  # Base class for nodes in the grammar.
  class ASTNode
    attr_accessor :line_number
    attr_accessor :column_number
    attr_accessor :filename
    attr_accessor :parent

    def location
      [@line_number, @column_number, @filename]
    end

    def location=(location)
      @line_number, @column_number, @filename = location
    end

    def self.inherited(klass)
      name = klass.simple_name.underscore

      klass.class_eval <<-EVAL, __FILE__, __LINE__ + 1
        def accept(visitor)
          visitor.visit_any self
          if visitor.visit_#{name} self
            accept_children visitor
          end
          visitor.end_visit_#{name} self
        end
      EVAL

      Visitor.class_eval <<-EVAL, __FILE__, __LINE__ + 1
        def visit_#{name}(node)
          true
        end

        def end_visit_#{name}(node)
        end
      EVAL
    end

    def accept_children(visitor)
    end

    def clone
      new_node = self.class.allocate
      new_node.location = location
      new_node.clone_from self
      new_node
    end

    def clone_from(other)
    end
  end

  # A container for one or many expressions.
  class Expressions < ASTNode
    include Enumerable

    attr_accessor :expressions

    def self.from(obj)
      case obj
      when nil
        nil
      when ::Array
        if obj.length == 0
          nil
        elsif obj.length == 1
          obj[0]
        else
          new obj
        end
      else
        obj
      end
    end

    def initialize(expressions = [])
      @expressions = expressions
      @expressions.each { |e| e.parent = self }
    end

    def each(&block)
      @expressions.each(&block)
    end

    def [](i)
      @expressions[i]
    end

    def last
      @expressions.last
    end

    def <<(exp)
      exp.parent = self
      @expressions << exp
    end

    def empty?
      @expressions.empty?
    end

    def accept_children(visitor)
      expressions.each { |exp| exp.accept visitor }
    end

    def ==(other)
      other.is_a?(Expressions) && other.expressions == expressions
    end

    def clone_from(other)
      @expressions = other.expressions.map(&:clone)
    end
  end

  # An array literal.
  #
  #  '[' ( expression ( ',' expression )* ) ']'
  #
  class ArrayLiteral < ASTNode
    attr_accessor :elements

    def initialize(elements = [])
      @elements = elements
      @elements.each { |e| e.parent = self }
    end

    def accept_children(visitor)
      elements.each { |exp| exp.accept visitor }
    end

    def ==(other)
      other.is_a?(ArrayLiteral) && other.elements == elements
    end

    def clone_from(other)
      @elements = other.elements.map(&:clone)
    end
  end

  class HashLiteral < ASTNode
    attr_accessor :key_values

    def initialize(key_values = [])
      @key_values = key_values
      @key_values.each { |kv| kv.parent = self }
    end

    def accept_children(visitor)
      key_values.each { |kv| kv.accept visitor }
    end

    def ==(other)
      other.is_a?(HashLiteral) && other.key_values == key_values
    end

    def clone_from(other)
      @key_values = other.key_values.map(&:clone)
    end
  end

  # Class definition:
  #
  #     'class' name [ '<' superclass ]
  #       body
  #     'end'
  #
  class ClassDef < ASTNode
    attr_accessor :name
    attr_accessor :body
    attr_accessor :superclass
    attr_accessor :type_vars
    attr_accessor :name_column_number

    def initialize(name, body = nil, superclass = nil, type_vars = nil, name_column_number = nil)
      @name = name
      @body = Expressions.from body
      @body.parent = self if @body
      @type_vars = type_vars
      @superclass = superclass
      @name_column_number = name_column_number
    end

    def accept_children(visitor)
      body.accept visitor if body
    end

    def ==(other)
      other.is_a?(ClassDef) && other.name == name && other.body == body && other.superclass == superclass && other.type_vars == type_vars
    end

    def clone_from(other)
      @name = other.name
      @body = other.body.clone
      @superclass = other.superclass
      @type_vars = other.type_vars
      @name_column_number = other.name_column_number
    end
  end

  # Module definition:
  #
  #     'module' name
  #       body
  #     'end'
  #
  class ModuleDef < ASTNode
    attr_accessor :name
    attr_accessor :body
    attr_accessor :name_column_number

    def initialize(name, body = nil, name_column_number = nil)
      @name = name
      @body = Expressions.from body
      @body.parent = self if @body
      @name_column_number = name_column_number
    end

    def accept_children(visitor)
      body.accept visitor if body
    end

    def ==(other)
      other.is_a?(ModuleDef) && other.name == name && other.body == body
    end

    def clone_from(other)
      @name = other.name
      @body = other.body.clone
      @name_column_number = other.name_column_number
    end
  end

  # The nil literal.
  #
  #     'nil'
  #
  class NilLiteral < ASTNode
    def ==(other)
      other.is_a?(NilLiteral)
    end
  end

  # A bool literal.
  #
  #     'true' | 'false'
  #
  class BoolLiteral < ASTNode
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      other.is_a?(BoolLiteral) && other.value == value
    end

    def clone_from(other)
      @value = other.value
    end
  end

  class NumberLiteral < ASTNode
    attr_accessor :value
    attr_reader :has_sign

    def initialize(value)
      @has_sign = value.is_a?(String) && (value[0] == '+' || value[0] == '-')
      @value = value
    end

    def clone_from(other)
      @value = other.value
    end
  end

  # An integer literal.
  #
  #     \d+
  #
  class IntLiteral < NumberLiteral
    def ==(other)
      other.is_a?(IntLiteral) && other.value.to_i == value.to_i
    end
  end

  # A long literal.
  #
  #     \d+L
  #
  class LongLiteral < NumberLiteral
    def ==(other)
      other.is_a?(LongLiteral) && other.value.to_i == value.to_i
    end
  end

  # A float literal.
  #
  #     \d+.\d+f
  #
  class FloatLiteral < NumberLiteral
    def ==(other)
      other.is_a?(FloatLiteral) && other.value.to_f == value.to_f
    end
  end

  # A double literal.
  #
  #     \d+.\d+
  #
  class DoubleLiteral < NumberLiteral
    def ==(other)
      other.is_a?(DoubleLiteral) && other.value.to_f == value.to_f
    end
  end

  # A char literal.
  #
  #     "'" \w "'"
  #
  class CharLiteral < ASTNode
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      other.is_a?(CharLiteral) && other.value.to_i == value.to_i
    end

    def clone_from(other)
      @value = other.value
    end
  end

  class StringLiteral < ASTNode
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      other.is_a?(StringLiteral) && other.value == value
    end

    def clone_from(other)
      @value = other.value
    end
  end

  class SymbolLiteral < ASTNode
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      other.is_a?(SymbolLiteral) && other.value == value
    end

    def clone_from(other)
      @value = other.value
    end
  end

  class RangeLiteral < ASTNode
    attr_accessor :from
    attr_accessor :to
    attr_accessor :exclusive

    def initialize(from, to, exclusive)
      @from = from
      @to = to
      @exclusive = exclusive
    end

    def ==(other)
      other.is_a?(RangeLiteral) && other.from == from && other.to == to && other.exclusive == exclusive
    end

    def clone_from(other)
      @from = other.from
      @to = other.to
      @exclusive = other.exclusive
    end
  end

  class RegexpLiteral < ASTNode
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      other.is_a?(RegexpLiteral) && other.value == value
    end

    def clone_from(other)
      @value = other.value
    end
  end

  # A method definition.
  #
  #     [ receiver '.' ] 'def' name
  #       body
  #     'end'
  #   |
  #     [ receiver '.' ] 'def' name '(' [ arg [ ',' arg ]* ] ')'
  #       body
  #     'end'
  #   |
  #     [ receiver '.' ] 'def' name arg [ ',' arg ]*
  #       body
  #     'end'
  #
  class Def < ASTNode
    attr_accessor :receiver
    attr_accessor :name
    attr_accessor :args
    attr_accessor :body
    attr_accessor :yields
    attr_accessor :maybe_recursive

    def initialize(name, args, body = nil, receiver = nil, yields = false)
      @name = name
      @args = args
      @args.each { |arg| arg.parent = self } if @args
      @body = Expressions.from body
      @body.parent = self if @body
      @receiver = receiver
      @receiver.parent = self if @receiver
      @yields = yields
    end

    def accept_children(visitor)
      receiver.accept visitor if receiver
      args.each { |arg| arg.accept visitor }
      body.accept visitor if body
    end

    def ==(other)
      other.is_a?(Def) && other.receiver == receiver && other.name == name && other.args == args && other.body == body && other.yields == yields
    end

    def clone_from(other)
      @name = other.name
      @args = other.args.map(&:clone)
      @body = other.body.clone
      @receiver = other.receiver.clone
      @yields = other.yields
      @maybe_recursive = other.maybe_recursive
    end
  end

  # A local variable or block argument.
  class Var < ASTNode
    attr_accessor :name
    attr_accessor :out

    def initialize(name, type = nil)
      @name = name.to_s
      @type = type
    end

    def ==(other)
      other.is_a?(Var) && other.name == name && other.type == type && other.out == out
    end

    def clone_from(other)
      @name = other.name
      @out = other.out
    end
  end

  # A global variable.
  class Global < ASTNode
    attr_accessor :name

    def initialize(name)
      @name = name.to_s
    end

    def ==(other)
      other.is_a?(Global) && other.name == name
    end

    def clone_from(other)
      @name = other.name
    end
  end

  # A def argument.
  class Arg < ASTNode
    attr_accessor :name
    attr_accessor :default_value
    attr_accessor :type_restriction
    attr_accessor :out

    def initialize(name, default_value = nil, type_restriction = nil)
      @name = name.to_s
      @default_value = default_value
      @default_value.parent = self if @default_value
      @type_restriction = type_restriction
      @type_restriction.parent = self if @type_restriction && @type_restriction != :self
    end

    def accept_children(visitor)
      default_value.accept visitor if default_value
      type_restriction.accept visitor if type_restriction && type_restriction != :self
    end

    def ==(other)
      other.is_a?(Arg) && other.name == name && other.default_value == default_value && other.type_restriction == type_restriction && other.out == out
    end

    def clone_from(other)
      @name = other.name
      @default_value = other.default_value.clone
      if other.type_restriction == :self
        @type_restriction = :self
      else
        @type_restriction = other.type_restriction.clone
      end
      @out = other.out
    end
  end

  # A qualified identifier.
  #
  #     const [ '::' const ]*
  #
  class Ident < ASTNode
    attr_accessor :names
    attr_accessor :global

    def initialize(names, global = false)
      @names = names
      @global = global
    end

    def ==(other)
      other.is_a?(Ident) && other.names == names && other.global == global
    end

    def clone_from(other)
      @names = other.names
      @global = other.global
    end
  end

  # An instance variable.
  class InstanceVar < ASTNode
    attr_accessor :name
    attr_accessor :out

    def initialize(name)
      @name = name
    end

    def ==(other)
      other.is_a?(InstanceVar) && other.name == name && other.out == out
    end

    def clone_from(other)
      @name = other.name
      @out = other.out
    end
  end

  class BinaryOp < ASTNode
    attr_accessor :left
    attr_accessor :right

    def initialize(left, right)
      @left = left
      @left.parent = self
      @right = right
      @right.parent = self
    end

    def accept_children(visitor)
      left.accept visitor
      right.accept visitor
    end

    def ==(other)
      self.class == other.class && other.left == left && other.right == right
    end

    def clone_from(other)
      @left = other.left.clone
      @right = other.right.clone
    end
  end

  # Expressions and.
  #
  #     expression '&&' expression
  #
  class And < BinaryOp
  end

  # Expressions or.
  #
  #     expression '||' expression
  #
  class Or < BinaryOp
  end

  # Expressions simple or (no short-circuit).
  #
  #     expression '||' expression
  #
  class SimpleOr < BinaryOp
  end

  # A method call.
  #
  #     [ obj '.' ] name '(' ')' [ block ]
  #   |
  #     [ obj '.' ] name '(' arg [ ',' arg ]* ')' [ block]
  #   |
  #     [ obj '.' ] name arg [ ',' arg ]* [ block ]
  #   |
  #     arg name arg
  #
  # The last syntax is for infix operators, and name will be
  # the symbol of that operator instead of a string.
  #
  class Call < ASTNode
    attr_accessor :obj
    attr_accessor :name
    attr_accessor :args
    attr_accessor :block

    attr_accessor :name_column_number
    attr_accessor :has_parenthesis
    attr_accessor :name_length

    def initialize(obj, name, args = [], block = nil, name_column_number = nil, has_parenthesis = false)
      @obj = obj
      @obj.parent = self if @obj
      @name = name
      @args = args || []
      @args.each { |arg| arg.parent = self }
      @block = block
      @block.parent = self if @block
      @name_column_number = name_column_number
      @has_parenthesis = has_parenthesis
    end

    def accept_children(visitor)
      obj.accept visitor if obj
      args.each { |arg| arg.accept visitor }
      block.accept visitor if block
    end

    def ==(other)
      other.is_a?(Call) && other.obj == obj && other.name == name && other.args == args && other.block == block
    end

    def clone_from(other)
      @obj = other.obj.clone
      @name = other.name
      @args = other.args.map(&:clone)
      @block = other.block.clone
      @name_column_number = other.name_column_number
      @name_length = other.name_length
      @has_parenthesis = other.has_parenthesis
    end

    def name_column_number
      @name_column_number || column_number
    end

    def name_length
      @name_length ||= name.to_s.end_with?('=') || name.to_s.end_with?('@') ? name.length - 1 : name.length
    end
  end

  # An if expression.
  #
  #     'if' cond
  #       then
  #     [
  #     'else'
  #       else
  #     ]
  #     'end'
  #
  # An if elsif end is parsed as an If whose
  # else is another If.
  class If < ASTNode
    attr_accessor :cond
    attr_accessor :then
    attr_accessor :else

    def initialize(cond, a_then = nil, a_else = nil)
      @cond = cond
      @cond.parent = self
      @then = Expressions.from a_then
      @then.parent = self if @then
      @else = Expressions.from a_else
      @else.parent = self if @else
    end

    def accept_children(visitor)
      self.cond.accept visitor
      self.then.accept visitor if self.then
      self.else.accept visitor if self.else
    end

    def ==(other)
      other.is_a?(If) && other.cond == cond && other.then == self.then && other.else == self.else
    end

    def clone_from(other)
      @cond = other.cond.clone
      @then = other.then.clone
      @else = other.else.clone
    end
  end

  # Assign expression.
  #
  #     target '=' value
  #
  class Assign < ASTNode
    attr_accessor :target
    attr_accessor :value

    def initialize(target, value)
      @target = target
      @target.parent = self
      @value = value
      @value.parent = self
    end

    def accept_children(visitor)
      target.accept visitor
      value.accept visitor
    end

    def ==(other)
      other.is_a?(Assign) && other.target == target && other.value == value
    end

    def clone_from(other)
      @target = other.target.clone
      @value = other.value.clone
    end
  end

  # Assign expression.
  #
  #     target [',' target]+ '=' value [',' value]*
  #
  class MultiAssign < ASTNode
    attr_accessor :targets
    attr_accessor :values

    def initialize(targets, values)
      @targets = targets
      @targets.each { |target| target.parent = self }
      @values = values
      @values.each { |value| value.parent = self }
    end

    def accept_children(visitor)
      @targets.each { |target| target.accept visitor }
      @values.each { |value| value.accept visitor }
    end

    def ==(other)
      other.is_a?(MultiAssign) && other.targets == targets && other.values == values
    end

    def clone_from(other)
      @targets = other.targets.map(&:clone)
      @values = other.values.map(&:clone)
    end
  end

  # While expression.
  #
  #     'while' cond
  #       body
  #     'end'
  #
  class While < ASTNode
    attr_accessor :cond
    attr_accessor :body
    attr_accessor :run_once

    def initialize(cond, body = nil, run_once = false)
      @cond = cond
      @cond.parent = self
      @body = Expressions.from body
      @body.parent = self if @body
      @run_once = run_once
    end

    def accept_children(visitor)
      cond.accept visitor
      body.accept visitor if body
    end

    def ==(other)
      other.is_a?(While) && other.cond == cond && other.body == body && other.run_once == run_once
    end

    def clone_from(other)
      @cond = other.cond.clone
      @body = other.body.clone
    end
  end

  # A code block.
  #
  #     'do' [ '|' arg [ ',' arg ]* '|' ]
  #       body
  #     'end'
  #   |
  #     '{' [ '|' arg [ ',' arg ]* '|' ] body '}'
  #
  class Block < ASTNode
    attr_accessor :args
    attr_accessor :body

    def initialize(args = [], body = nil)
      @args = args
      @args.each { |arg| arg.parent = self } if @args
      @body = Expressions.from body
      @body.parent = self if @body
    end

    def accept_children(visitor)
      args.each { |arg| arg.accept visitor }
      body.accept visitor if body
    end

    def ==(other)
      other.is_a?(Block) && other.args == args && other.body == body
    end

    def clone_from(other)
      @args = other.args.map(&:clone)
      @body = other.body.clone
    end
  end

  ['return', 'break', 'next', 'yield'].each do |keyword|
    # A #{keyword} expression.
    #
    #     '#{keyword}' [ '(' ')' ]
    #   |
    #     '#{keyword}' '(' arg [ ',' arg ]* ')'
    #   |
    #     '#{keyword}' arg [ ',' arg ]*
    #
    class_eval <<-EVAL, __FILE__, __LINE__ + 1
      class #{keyword.capitalize} < ASTNode
        attr_accessor :exps

        def initialize(exps = [])
          @exps = exps
          @exps.each { |exp| exp.parent = self }
        end

        def accept_children(visitor)
          exps.each { |e| e.accept visitor }
        end

        def ==(other)
          other.is_a?(#{keyword.capitalize}) && other.exps == exps
        end

        def clone_from(other)
          @exps = other.exps.map(&:clone)
        end
      end
    EVAL
  end

  class LibDef < ASTNode
    attr_accessor :name
    attr_accessor :libname
    attr_accessor :body
    attr_accessor :name_column_number

    def initialize(name, libname = nil, body = nil, name_column_number = nil)
      @name = name
      @libname = libname
      @body = Expressions.from body
      @body.parent = self if @body
      @name_column_number = name_column_number
    end

    def accept_children(visitor)
      body.accept visitor if body
    end

    def ==(other)
      other.is_a?(LibDef) && other.name == name && other.libname == libname && other.body == body
    end
  end

  class FunDef < ASTNode
    attr_accessor :name
    attr_accessor :args
    attr_accessor :return_type
    attr_accessor :ptr
    attr_accessor :varargs
    attr_accessor :real_name

    def initialize(name, args = [], return_type = nil, ptr = 0, varargs = false, real_name = name)
      @name = name
      @real_name = real_name
      @args = args
      @args.each { |arg| arg.parent = self }
      @return_type = return_type
      @return_type.parent = self if @return_type
      @ptr = ptr
      @varargs = varargs
    end

    def accept_children(visitor)
      args.each { |arg| arg.accept visitor }
      return_type.accept visitor if return_type
    end

    def ==(other)
      other.is_a?(FunDef) && other.name == name && other.args == args && other.return_type == return_type && other.ptr == ptr && other.real_name == real_name && other.varargs == varargs
    end
  end

  class FunDefArg < ASTNode
    attr_accessor :name
    attr_accessor :type
    attr_accessor :ptr
    attr_accessor :out

    def initialize(name, type, ptr = 0, out = false)
      @name = name
      @type = type
      @ptr = ptr
      @out = out
    end

    def accept_children(visitor)
      type.accept visitor
    end

    def ==(other)
      other.is_a?(FunDefArg) && other.name == name && other.type == type && other.ptr == ptr && other.out == out
    end
  end

  class TypeDef < ASTNode
    attr_accessor :name
    attr_accessor :type
    attr_accessor :ptr
    attr_accessor :name_column_number

    def initialize(name, type, ptr = 0, name_column_number = nil)
      @name = name
      @type = type
      @ptr = ptr

      @name_column_number = name_column_number
    end

    def accept_children(visitor)
      type.accept visitor
    end

    def ==(other)
      other.is_a?(TypeDef) && other.name == name && other.type == type && other.ptr == ptr
    end
  end

  class StructDef < ASTNode
    attr_accessor :name
    attr_accessor :fields

    def initialize(name, fields = [])
      @name = name
      @fields = fields
    end

    def accept_children(visitor)
      fields.each { |field| field.accept visitor }
    end

    def ==(other)
      other.is_a?(StructDef) && other.name == name && other.fields == fields
    end
  end

  class Include < ASTNode
    attr_accessor :name

    def initialize(name)
      @name = name
      @name.parent = self
    end

    def accept_children(visitor)
      name.accept visitor
    end

    def ==(other)
      other.is_a?(Include) && other.name == name
    end

    def clone_from(other)
      @name = other.name
    end
  end

  class Macro < ASTNode
    attr_accessor :receiver
    attr_accessor :name
    attr_accessor :args
    attr_accessor :body

    def initialize(name, args, body = nil, receiver = nil)
      @name = name
      @args = args
      @args.each { |arg| arg.parent = self } if @args
      @body = Expressions.from body
      @body.parent = self if @body
      @receiver = receiver
      @receiver.parent = self if @receiver
    end

    def accept_children(visitor)
      receiver.accept visitor if receiver
      args.each { |arg| arg.accept visitor }
      body.accept visitor if body
    end

    def ==(other)
      other.is_a?(Macro) && other.receiver == receiver && other.name == name && other.args == args && other.body == body
    end

    def clone_from(other)
      @name = other.name
      @args = other.args.map(&:clone)
      @body = other.body.clone
      @receiver = other.receiver.clone
    end

    def yields
      false
    end
  end

  class PointerOf < ASTNode
    attr_accessor :var

    def initialize(var)
      @var = var
    end

    def accept_children(visitor)
      var.accept visitor
    end

    def ==(other)
      other.is_a?(PointerOf) && other.var == var
    end

    def clone_from(other)
      @var = other.var.clone
    end
  end

  class IsA < ASTNode
    attr_accessor :obj
    attr_accessor :const

    def initialize(obj, const)
      @obj = obj
      @const = const
    end

    def accept_children(visitor)
      obj.accept visitor
      const.accept visitor
    end

    def ==(other)
      other.is_a?(IsA) && other.obj == obj && other.const == const
    end

    def clone_from(other)
      @obj = other.obj.clone
      @const = other.const.clone
    end
  end

  class Require < ASTNode
    attr_accessor :string

    def initialize(string)
      @string = string
      @string.parent = self
    end

    def accept_children(visitor)
      string.accept visitor
    end

    def ==(other)
      other.is_a?(Require) && other.string == string
    end

    def clone_from(other)
      @string = other.string.clone
    end
  end

  class Case < ASTNode
    attr_accessor :cond
    attr_accessor :whens
    attr_accessor :else

    def initialize(cond, whens, a_else = nil)
      @cond = cond
      @cond.parent = self
      @whens = whens
      @whens.each { |w| w.parent = self }
      @else = a_else
      @else.parent = self if @else
    end

    def accept_children(visitor)
      @whens.each { |w| w.accept visitor }
      @else.accept visitor if @else
    end

    def ==(other)
      other.is_a?(Case) && other.cond == cond && other.whens == whens && other.else == @else
    end

    def clone_from(other)
      @cond = other.cond.clone
      @whens = other.whens.map(&:clone)
      @else = other.else.clone
    end
  end

  class When < ASTNode
    attr_accessor :conds
    attr_accessor :body

    def initialize(conds, body = nil)
      @conds = conds
      @conds.each { |cond| cond.parent = self }
      @body = Expressions.from body
      @body.parent = self if @body
    end

    def accept_children(visitor)
      conds.each { |cond| cond.accept visitor }
      body.accept visitor if body
    end

    def ==(other)
      other.is_a?(When) && other.conds == conds && other.body == body
    end

    def clone_from(other)
      @conds = other.conds.map(&:clone)
      @body = other.body.clone
    end
  end
end
