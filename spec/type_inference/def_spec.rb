require 'spec_helper'

describe 'Type inference: def' do
  it "types a call with an int" do
    assert_type('def foo; 1; end; foo') { int }
  end

  it "types a call with a float" do
    assert_type('def foo; 2.3f; end; foo') { float }
  end

  it "types a call with a double" do
    assert_type('def foo; 2.3; end; foo') { double }
  end

  it "types a call with an argument" do
    input = parse 'def foo(x); x; end; foo 1'
    mod = infer_type input
    input.last.type.should eq(mod.int)
  end

  it "types a call with an argument" do
    input = parse 'def foo(x); x; end; foo 1; foo 2.3'
    mod = infer_type input
    input[1].type.should eq(mod.int)
    input[2].type.should eq(mod.double)
  end

  it "types a call with an argument uses a new scope" do
    assert_type('x = 2.3; def foo(x); x; end; foo 1; x') { double }
  end

  it "assigns def owner" do
    input = parse 'class Int; def foo; 2.5; end; end; 1.foo'
    mod = infer_type input
    input.last.target_def.owner.should eq(mod.int)
  end

  it "types putchar with Char" do
    assert_type(%q(require "io"; C.putchar 'a')) { char }
  end

  it "types getchar with Char" do
    assert_type(%q(require "io"; C.getchar)) { char }
  end

  it "allows recursion" do
    input = parse "def foo; foo; end; foo"
    infer_type input
  end

  it "allows recursion with arg" do
    input = parse "def foo(x); foo(x); end; foo 1"
    infer_type input
  end

  it "types simple recursion" do
    assert_type('def foo(x); if x > 0; foo(x - 1) + 1; else; 1; end; end; foo(5)') { int }
  end

  it "types recursion" do
    input = parse 'def foo(x); if x > 0; foo(x - 1) + 1; else; 1; end; end; foo(5)'
    mod = infer_type input
    input.last.type.should eq(mod.int)
    input.last.target_def.body.then.type.should eq(mod.int)
  end

  it "types recursion 2" do
    input = parse 'def foo(x); if x > 0; 1 + foo(x - 1); else; 1; end; end; foo(5)'
    mod = infer_type input
    input.last.type.should eq(mod.int)
    input.last.target_def.body.then.type.should eq(mod.int)
  end

  it "types mutual recursion" do
    input = parse 'def foo(x); if true; bar(x); else; 1; end; end; def bar(x); foo(x); end; foo(5)'
    mod = infer_type input
    input.last.type.should eq(mod.int)
    input.last.target_def.body.then.type.should eq(mod.int)
  end

  it "types empty body def" do
    assert_type('def foo; end; foo') { self.nil }
  end

  it "types infinite recursion" do
    assert_type('def foo; foo; end; foo') { self.nil }
  end

  it "types mutual infinite recursion" do
    assert_type('def foo; bar; end; def bar; foo; end; foo') { self.nil }
  end

  it "types call with union argument" do
    assert_type('def foo(x); x; end; a = 1; a = 1.1; foo(a)') { UnionType.new(int, double) }
  end

  it "doesn't incorrectly type as recursive type" do
    assert_type(%Q(
      class Foo[]
        #{rw :value}
      end

      f = Foo.new
      f.value = Foo.new
      f.value.value = Foo.new
      f
      )
  ) { ObjectType.new('Foo').generic!.with_var('@value', ObjectType.new('Foo').generic!.with_var('@value', ObjectType.new('Foo').generic!)) }
  end

  it "defines class method" do
    assert_type("def Int.foo; 2.5; end; Int.foo") { double }
  end

  it "defines class method with self" do
    assert_type("class Int; def self.foo; 2.5; end; end; Int.foo") { double }
  end

  it "calls with default argument" do
    assert_type("def foo(x = 1); x; end; foo") { int }
  end

  it "do not use body for the def type" do
    input = parse 'def foo; if false; return 0; end; end; foo'
    mod = infer_type input
    input.last.type.should eq(UnionType.new(mod.int, mod.nil))
    input.last.target_def.body.type.should eq(mod.nil)
  end

  it "types as nilable if used after scope where defined" do
    assert_type("if false; a = 1; end; a") { [int, self.nil].union }
  end

  it "doesn't type as nilable if used inside same scope" do
    input = parse 'if false; a = 1; end'
    mod = infer_type input
    input.then.target.type.should eq(mod.int)
  end
end
