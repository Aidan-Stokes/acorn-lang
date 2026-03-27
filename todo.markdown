Acorn Programming Language

Acorn is a compiled systems programming language with:

Odin-inspired syntax

Explicit dataflow assignment (<-)

fn instead of proc

Multiple return values

Pipeline operators

Fast native compilation

File extension:

.ac

Example program:

add :: fn(a: int, b: int) -> int {
    return a + b
}

main :: fn() {

    result <- add(10, 5)

    print(result)

}
Key Syntax Design
Assignment (Dataflow)

Values flow right → left.

x <- 10
y <- x + 5

This visually represents:

10 → x
x + 5 → y
Function Definition

Acorn replaces Odin’s proc with fn.

add :: fn(a: int, b: int) -> int {
    return a + b
}
Multiple Returns
divmod :: fn(a: int, b: int) -> (int, int) {
    return a / b, a % b
}

q, r <- divmod(10, 3)
Pipeline Operator

Acorn also supports functional pipelines.

result <-
    numbers
    |> filter(is_even)
    |> map(square)
    |> sum()

Equivalent to:

tmp1 <- filter(numbers)
tmp2 <- map(tmp1)
result <- sum(tmp2)
Example Real Program
square :: fn(x: int) -> int {
    return x * x
}

is_even :: fn(x: int) -> bool {
    return x % 2 == 0
}

main :: fn() {

    numbers <- [1,2,3,4,5,6]

    result <-
        numbers
        |> filter(is_even)
        |> map(square)
        |> sum()

    print(result)

}
Compiler Architecture (Written in Odin)

Suggested project layout:

acorn/
 ├─ lexer/
 ├─ parser/
 ├─ ast/
 ├─ typechecker/
 ├─ ir/
 ├─ codegen/
 ├─ cli/
 └─ stdlib/
Compiler Pipeline
source (.ac)
   ↓
lexer
   ↓
parser
   ↓
AST
   ↓
type checker
   ↓
IR
   ↓
codegen
   ↓
native binary
AST Design (Odin)

Example AST structures.

Node_Kind :: enum {
    Int_Literal,
    Binary_Expr,
    Var_Decl,
    Fn_Decl,
    Call_Expr,
}

Node :: struct {
    kind: Node_Kind
}

Expression example:

Binary_Expr :: struct {
    left: ^Node
    operator: string
    right: ^Node
}

Function declaration:

Fn_Decl :: struct {
    name: string
    params: []Param
    return_type: Type
    body: []^Node
}
Lexer Tokens

Tokens needed:

IDENT
INT
STRING

FN
STRUCT
ENUM
RETURN
IF
ELSE
FOR

ARROW <- 
PIPE |>
COLON :
DOUBLE_COLON ::
COMMA ,

Token struct:

Token :: struct {
    kind: Token_Kind
    lexeme: string
    line: int
}
Parser Example (Assignment)

For:

x <- 10

Parser creates:

Assign
 ├─ target: x
 └─ value: 10

Odin struct:

Assign_Stmt :: struct {
    target: string
    value: ^Node
}
Implementing <- in Parser

Pseudo Odin:

parse_assignment :: proc(p: ^Parser) -> ^Node {

    name := parse_identifier(p)

    expect(p, Token_LeftArrow)

    value := parse_expression(p)

    return new_assign(name, value)
}
Pipeline Operator Parsing
a |> b |> c

Transforms to:

c(b(a))

Parser transformation:

Pipe
 ├─ left
 └─ call

Or converted directly during parsing.

Code Generation Options

Three good backends:

1️⃣ LLVM

Best performance.

Libraries:

LLVM-C
2️⃣ Cranelift (recommended)

Very fast compile times.

Projects like:

Wasmtime

Rust JIT

3️⃣ C backend (easiest)

Generate C code:

acorn → C → clang → binary

This is how Zig originally bootstrapped.

Example Generated C

Acorn:

result <- add(3,4)

Generated C:

int result = add(3,4);
Standard Library

Minimum modules:

std.io
std.math
std.mem
std.fs
std.str

Example:

import std.io

main :: fn() {
    io.print("Hello Acorn")
}
CLI Design
acorn build main.ac
acorn run main.ac
acorn fmt
acorn check
Recommended Roadmap
Phase 1

Lexer
Parser
AST
Interpreter

Phase 2

Type checker

Phase 3

LLVM / Cranelift backend

Phase 4

Standard library

Example Acorn Code
Person :: struct {
    name: string
    age: int
}

main :: fn() {

    p <- Person{name="Alice", age=30}

    print(p.name)

}

✅ Important advantage of writing the compiler in Odin

You get:

extremely fast builds

easy memory management

simple C interop

good performance

Many modern languages follow this approach (self-host later).
