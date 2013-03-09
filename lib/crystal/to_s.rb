module Crystal
  class ASTNode
    def to_s
      visitor = ToSVisitor.new
      self.accept visitor
      visitor.to_s
    end
  end

  class ToSVisitor < Visitor
    def initialize
      @str = ""
      @indent = 0
    end

    def visit_allocate(node)
      @str << 'allocate()'
    end

    def visit_nil_literal(node)
      @str << 'nil'
    end

    def visit_bool_literal(node)
      @str << (node.value ? 'true' : 'false')
    end

    def visit_int_literal(node)
      @str << node.value.to_s
    end

    def visit_float_literal(node)
      @str << node.value.to_s
    end

    def visit_double_literal(node)
      @str << node.value.to_s
    end

    def visit_char_literal(node)
      @str << "'"
      @str << node.value.chr
      @str << "'"
    end

    def visit_string_literal(node)
      @str << '"'
      @str << node.value.gsub('"', "\\\"")
      @str << '"'
    end

    def visit_symbol_literal(node)
      @str << ':'
      @str << node.value
    end

    def visit_range_literal(node)
      node.from.accept self
      if node.exclusive
        @str << '..'
      else
        @str << '...'
      end
      node.to.accept self
      false
    end

    def visit_regexp_literal(node)
      @str << '/'
      @str << node.value
      @str << '/'
    end

    def visit_array_literal(node)
      @str << '['
      node.elements.each_with_index do |exp, i|
        @str << ', ' if i > 0
        exp.accept self
      end
      @str << ']'
      false
    end

    def visit_hash_literal(node)
      @str << '{'
      node.key_values.each_slice(2).each_with_index do |kv, i|
        @str << ', ' if i > 0
        kv[0].accept self
        @str << ' => '
        kv[1].accept self
      end
      @str << '}'
      false
    end

    def visit_and(node)
      to_s_binary node, '&&'
    end

    def visit_or(node)
      to_s_binary node, '||'
    end

    def visit_simple_or(node)
      to_s_binary node, '||'
    end

    def to_s_binary(node, op)
      node.left.accept self
      @str << ' '
      @str << op
      @str << ' '
      node.right.accept self
      false
    end

    def visit_call(node)
      if node.obj && node.name == :'[]'
        node.obj.accept self
        @str << "["
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << "]"
      elsif node.obj && node.name == :'[]='
        node.obj.accept self
        @str << "["
        node.args[0].accept self
        @str << "] = "
        node.args[1].accept self
      elsif node.obj && !is_alpha(node.name) && node.args.length == 0
        if node.name.to_s.end_with? '@'
          @str << node.name[0 ... -1].to_s
        else
          @str << node.name.to_s
        end
        @str << "("
        node.obj.accept self
        @str << ")"
      elsif node.obj && !is_alpha(node.name) && node.args.length == 1
        node.obj.accept self
        @str << " "
        @str << node.name.to_s
        @str << " "
        node.args[0].accept self
      else
        if node.obj
          node.obj.accept self
          @str << "."
        end
        @str << node.name.to_s
        @str << "(" unless node.obj && node.args.empty?
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << ")" unless node.obj && node.args.empty?
      end
      if node.block
        @str << " "
        node.block.accept self
      end
      false
    end

    def visit_require(node)
      @str << 'require '
      node.string.accept self
      false
    end

    def is_alpha(string)
      c = string.to_s[0].downcase
      'a' <= c && c <= 'z'
    end

    def visit_block(node)
      @str << "do"

      unless node.args.empty?
        @str << " |"
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << "|"
      end

      @str << "\n"
      accept_with_indent(node.body)

      append_indent
      @str << "end"

      false
    end

    def visit_def(node)
      @str << "def "
      if node.receiver
        node.receiver.accept self
        @str << "."
      end
      @str << node.name.to_s
      if node.args.length > 0
        @str << "("
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
          i += 1

        end
        @str << ")"
      end
      @str << "\n"
      accept_with_indent(node.body)
      append_indent
      @str << "end"
      false
    end

    def visit_macro(node)
      @str << "macro "
      if node.receiver
        node.receiver.accept self
        @str << "."
      end
      @str << node.name.to_s
      if node.args.length > 0
        @str << "("
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
          i += 1

        end
        @str << ")"
      end
      @str << "\n"
      accept_with_indent(node.body)
      append_indent
      @str << "end"
      false
    end

    def visit_frozen_def(node)
      visit_def(node)
      false
    end

    def visit_external(node)
      visit_def(node)
      false
    end

    def visit_var(node)
      if node.name
        @str << node.name
      else
        @str << '?'
      end
    end

    def visit_global(node)
      @str << node.name
    end

    def visit_arg(node)
      @str << 'out ' if node.out
      if node.name
        @str << node.name
      else
        @str << '?'
      end
      if node.default_value
        @str << ' = '
        node.default_value.accept self
      end
      if node.type_restriction
        @str << ' : '
        if node.type_restriction == :self
          @str << 'self'
        else
          node.type_restriction.accept self
        end
      end
      false
    end

    def visit_ident(node)
      node.names.each_with_index do |name, i|
        @str << '::' if i > 0 || node.global
        @str << name
      end
    end

    def visit_instance_var(node)
      @str << node.name
    end

    def visit_expressions(node)
      node.expressions.each do |exp|
        append_indent
        exp.accept self
        @str << "\n"
      end
      false
    end

    def visit_if(node)
      @str << "if "
      node.cond.accept self
      @str << "\n"
      accept_with_indent(node.then)
      if node.else
        append_indent
        @str << "else\n"
        accept_with_indent(node.else)
      end
      append_indent
      @str << "end"
      false
    end

    def visit_class_def(node)
      @str << "class "
      @str << node.name
      if node.type_vars
        @str << "["
        node.type_vars.each_with_index do |type_var, i|
          @str << ", " if i > 0
          @str << type_var
        end
        @str << "]"
      end
      if node.superclass
        @str << " < "
        node.superclass.accept self
      end
      @str << "\n"
      accept_with_indent(node.body)
      @str << "end"
      false
    end

    def visit_module_def(node)
      @str << "module "
      @str << node.name
      @str << "\n"
      accept_with_indent(node.body)
      @str << "end"
      false
    end

    def visit_include(node)
      @str << "include "
      node.name.accept self
      false
    end

    def visit_assign(node)
      node.target.accept self
      @str << " = "
      node.value.accept self
      false
    end

    def visit_multi_assign(node)
      node.targets.each_with_index do |target, i|
        @str << ", " if i > 0
        target.accept self
      end
      @str << " = "
      node.values.each_with_index do |value, i|
        @str << ", " if i > 0
        value.accept self
      end
      false
    end

    def visit_while(node)
      if node.run_once
        if node.body.is_a?(Expressions)
          @str << "begin\n"
          accept_with_indent(node.body)
          append_indent
          @str << "end while "
        else
          node.body.accept self
          @str << " while "
        end
        node.cond.accept self
      else
        @str << "while "
        node.cond.accept self
        @str << "\n"
        accept_with_indent(node.body)
        append_indent
        @str << "end"
      end
      false
    end

    def visit_lib_def(node)
      @str << "lib "
      @str << node.name
      if node.libname
        @str << "('"
        @str << node.libname
        @str << "')"
      end
      @str << "\n"
      accept_with_indent(node.body)
      append_indent
      @str << 'end'
      false
    end

    def visit_fun_def(node)
      @str << 'fun '
      if node.name == node.real_name
        @str << node.name
      else
        @str << node.name
        @str << ' = '
        @str << node.real_name
      end
      if node.args.length > 0
        @str << '('
        node.args.each_with_index do |arg, i|
          @str << ', ' if i > 0
          arg.accept self
        end
        if node.varargs
          @str << ', ...'
        end
        @str << ')'
      end
      if node.return_type
        @str << ' : '
        node.return_type.accept self
        node.ptr.times do
          @str << '*'
        end
      end
      false
    end

    def visit_fun_def_arg(node)
      @str << node.name.to_s
      @str << ' : '
      @str << 'out ' if node.out
      node.type.accept self
      node.ptr.times do
        @str << '*'
      end
      false
    end

    def visit_type_def(node)
      @str << 'type '
      @str << node.name.to_s
      @str << ' : '
      node.type.accept self
      node.ptr.times do
        @str << '*'
      end
      false
    end

    def visit_struct_def(node)
      @str << 'struct '
      @str << node.name.to_s
      @str << "\n"
      with_indent do
        node.fields.each do |field|
          append_indent
          field.accept self
          @str << "\n"
        end
      end
      append_indent
      @str << 'end'
      false
    end

    def visit_pointer_of(node)
      node.var.accept(self)
      @str << '.ptr'
      false
    end

    def visit_is_a(node)
      node.obj.accept self
      @str << ".is_a?("
      node.const.accept self
      @str << ")"
      false
    end

    def visit_case(node)
      @str << 'case '
      node.cond.accept self
      @str << "\n"
      node.whens.each do |wh|
        wh.accept self
      end
      if node.else
        @str << "else\n"
        accept_with_indent node.else
      end
      @str << 'end'
      false
    end

    def visit_when(node)
      @str << 'when '
      node.conds.each_with_index do |cond, i|
        @str << ', ' if i > 0
        cond.accept self
      end
      @str << "\n"
      accept_with_indent node.body
      false
    end

    ['return', 'next', 'break', 'yield'].each do |keyword|
      class_eval <<-EVAL, __FILE__, __LINE__ + 1
        def visit_#{keyword}(node)
          @str << '#{keyword}'
          if node.exps.length > 0
            @str << ' '
            node.exps.each_with_index do |exp, i|
              @str << ", " if i > 0
              exp.accept self
            end
          end
          false
        end
      EVAL
    end

    def with_indent
      @indent += 1
      yield
      @indent -= 1
    end

    def accept_with_indent(node)
      return unless node
      is_expressions = node.is_a?(Expressions)
      with_indent do
        append_indent unless is_expressions
        node.accept self
      end
      @str << "\n" unless is_expressions
    end

    def append_indent
      @str << ('  ' * @indent)
    end

    def to_s
      @str.strip
    end
  end
end
