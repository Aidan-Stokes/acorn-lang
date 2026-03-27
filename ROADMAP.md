# Acorn 1.0 - Implementation Roadmap

## Recent Fixes (2026-03-24)

### Module Verification
- Added `verify_module` procedure using `LLVMVerifyModule`
- Module is verified before outputting IR
- Verification catches type mismatches and invalid IR
- Module verification step shows in verbose mode

### Fixed: Constant Type Mismatch
- Global constants now infer correct type from value
- `x = 42` now correctly creates i64 constant (was i32 mismatch)
- Added `get_llvm_type_for_value` helper for type inference

### Assembly and Object File Output
- Added `-S` flag to output LLVM IR/assembly (.s file)
- Added `-c` flag to output object file (.o file)
- Default behavior produces executable
- Output file can be set with `-o` flag
- Added `Output_Type` enum in `common` package

### Verbose/Debug Flags
- Added `--verbose` / `-vv` flags to show compilation stages
- Shows colored output: blue for stage headers, yellow for individual stages
- Works with `build`, `run`, `check`, and `fmt` commands
- Output shows: Lexing, Parsing, Type checking, Generating LLVM IR, Writing IR, Linking

### Version Command
- Added `VERSION` constant in main.odin
- Added `print_version` procedure
- `acorn --version` and `acorn -v` both output "Acorn compiler version 1.0.0"

### Global Variables
- Added `generate_llvm_global_assign` for top-level assignments (`x <- 10`)
- Global variables stored with `LLVMAddGlobal` and initialized with `LLVMSetInitializer`
- Variable shadowing works correctly: local variables shadow globals
- Reassignment inside functions works: `x <- 10; main() { x <- 20; print(x) }` prints 20

### Constant Type Inference
- Fixed type checker to infer type from value when no explicit type specified
- Constants like `x = 10` now work correctly without `x: int = 10`
- Type is checked from `node.value.type` when `node.return_type.name` is empty

### Linker Script Fix
- Added `-filetype=obj` flag to `llc` command in `/tmp/acorn_linker`
- Ensures object file is generated in correct format instead of assembly

### Global Constants
- Constants can be declared at top level: `x = 42`, `x: int = 10`, `x: f64 = 3.14`
- Multiple constants in sequence work: `x = 10\ny = 5\nprint(x + y)`
- All 54 tests pass including 7 constant/global variable tests

## Previous Fixes (2026-03-22)

### Enum Support
- Added `Enum_Variant` struct in AST with name and value fields
- Added `enum_variants` field to Node struct
- Added `new_enum_decl` function in AST
- Added `parse_enum_decl_with_name` parser for both `enum { }` and `name :: enum { }` syntax
- Added `peek_next` helper to look at next token without consuming
- Fixed trailing comma handling in enum parsing
- Added `enum_variants` map in codegen for tracking declared enums
- Added `find_enum_variant_value` helper function
- Added `generate_llvm_enum` for processing enum declarations
- Modified `Member_Expr` codegen to handle `EnumName.Variant` syntax
- Enum variants compile to integer constants (Int=0, Float=1, String=2)

### Raw Strings
- Added `RAW_STRING` token type to lexer
- Added `scan_raw_string` function for backtick strings
- Raw strings don't process escape sequences
- Useful for Windows paths, regex patterns, and JSON

### Block Comments
- Added block comment handling in `skip_whitespace`
- Supports `/* ... */` syntax spanning multiple lines

### Match/Switch Expressions
- Added `MATCH` and `CASE_ARROW` tokens
- Added `Match_Stmt` node with value, patterns, and cases
- Added `parse_match_stmt` to parser
- Added match statement codegen with if-else chain
- Supports enum variants and expressions as case patterns

### Struct Support
- Added `Struct_Decl` node type in AST
- Added struct field parsing with `if !match(p, .COMMA) { break }` pattern
- Added `LLVMStructCreateNamed`, `LLVMStructSetBody`, `LLVMStructGetTypeAtIndex` to LLVM bindings
- Added `struct_types` and `struct_fields` maps for tracking declared structs
- Added `generate_llvm_struct` to create LLVM struct types
- Added struct literal codegen with proper type conversion
- Added `Member_Expr` codegen for field access (`p.x`, `p.y`)
- Fixed struct variable storage to copy struct values, not pointers
- Added `struct_type` field to Var_Entry and ValueInfo for struct type tracking

## Previous Fixes (2026-03-20)

### Parser Fixes
- Fixed `->` token not being recognized in lexer (was being parsed as two tokens: GREATER + MINUS)
- Fixed function call vs function definition detection in `parse_statement`
- Function definitions like `main() -> int { ... }` now correctly parsed without `fn` keyword
- Function calls like `print(42)` no longer incorrectly parsed as function definitions
- Fixed memory corruption bug where `delete(params)` freed params slice backing memory
- Clone lexeme strings in parser to prevent dangling pointers

### Memory Management
- Simplified lexer to avoid global token stream allocations
- Fixed #soa Var_Store in codegen
- Memory tracking available with `-define:TRACK_ALLOCATOR=true`

### Character & String Support
- Added character literals (`'a'`, `'\n'`, `'\x41'`)
- Added string escape sequences (`\n`, `\t`, `\"`, `\\`, `\'`, `\0`, `\xNN`)
- Fixed lexer string scanning bug that skipped first character

### Backend Cleanup
- Removed broken C backend to simplify codebase
- LLVM backend is now the sole code generation target

### Input/Output
- Added `LLVMGetNamedGlobal` and `LLVMAddGlobal` to LLVM bindings
- `read_line()` and `input()` now work using `scanf` with `" %4095[^\n]"` format
- Leading space in format skips whitespace between reads

### Proper Return Types
- Functions now return correct LLVM types (void, i32, i64, f32, f64, etc.)
- Default return type is `int` (i64) for `main`, `void` for other functions
- Added `LLVMVoidType` to LLVM bindings
- Fixed `f32` to use `LLVMFloatType` instead of `LLVMDoubleType`

## Language Summary

Acorn is a simple, expressive programming language inspired by Odin and Rust. It prioritizes readability and simplicity while maintaining enough power for practical programming.

### Design Goals
- Clean, minimal syntax
- Strong type inference where possible
- Familiar to programmers coming from C, R, or Odin
- Fast compilation via LLVM backend

### Current Syntax

```acorn
// Function declaration (Odin-style with ::)
main :: fn() -> int {
    print(1)
}

// Variable assignment with arrow
x <- 1
y <- x + 2

// Type annotations
i: int <- 42
f: f32 <- 3.14
b: bool <- true
s: str <- "hello"
arr: []int <- [1, 2, 3]

// Integer types: int (usize_t/u64), u (uint/u64), i32, i16, i8, u8, byte, u16, u32, u64, i64
// Float types: f32, f64
// Other: bool, char, rune, string
// Boolean: bool
// Character: char
// String: str

// Function calls
print("Hello, World!")
print(42)
println("with newline")

// Control flow
if (x > 0) {
    print("positive")
} else {
    print("non-positive")
}

// Loops - Odin-style
for i in 0..10 {
    print(i)
}

for i in 0..10 by 2 {
    print(i)
}

for x < 10 {
    x <- x + 1
}

for {
    if x > 100 { break }
}

// break and continue supported
if (x == 5) {
    break
}
if (x == 3) {
    continue
}

// Boolean literals
flag <- true

// Array literals
arr <- [1, 2, 3]
print(arr[0])  // prints 1

// Typed array declarations
arr: []int <- [1, 2, 3]

// Float literals
pi <- 3.14159

// Character literals
c <- 'a'
newline <- '\n'

// String escape sequences
msg <- "Hello\nWorld\t!"
```

### Planned Syntax Extensions

```acorn
// Pipes (function composition)
result <- value |> transform |> process

// Iterating over arrays
for item, index in arr {
    print(index, item)
}

// Structs (IMPLEMENTED)
Point :: struct {
    x: int
    y: int
}

// Struct literals (IMPLEMENTED)
p <- Point{x: 10, y: 20}

// Enums (IMPLEMENTED)
Color :: enum {
    Red
    Green
    Blue
}

// Scientific notation
scientific <- 1e-10

match color {
    Red   => print("red")
    Green => print("green")
    Blue  => print("blue")
}

// Type annotations
x: int <- 42
y: float <- 3.14

// Import statements
import "math"

// Struct literals with inferred types
p <- Point{10, 20}

// Comments
// Single line comment
/*
 * Block comment
 */

// Raw strings
path <- `"C:\Users\name"`

// Function types
callback: fn(int, int) -> int

// Generics (future)
Container<T> :: struct {
    value: T
}
```

---

## Core Language Features

### Lexer
- [x] Float literals (`3.14`)
- [x] Scientific notation (`1e10`, `1.5e-3`, `3.14e+5`)
- [x] Multi-char operators (`==`, `!=`, `<=`, `>=`)
- [x] String escape sequences (`\n`, `\t`, `\"`, `\\`, `\'`, `\0`, `\xNN`)
- [x] Character literals (`'a'`, `'\n'`, `'\x41'`)
- [x] Block comments (`/* */`)
- [x] Raw strings (backticks)

### Parser
- [x] Enum declarations (`enum Color { Red, Green, Blue }`)
- [x] Import statements (syntax; no module resolution yet)
- [x] Struct literals (`Point{x: 1, y: 2}`)
- [x] Struct declarations (`Point :: struct { x: int, y: int }`)
- [x] Struct member access (`p.x`)
- [x] Float literals (basic decimal)
- [x] Type annotations on variables (`x: int <- expr`, `arr: []int <- [1, 2, 3]`)
- [x] Break/continue statements
- [x] Odin-style `for` loops (`for x in range`, `for condition`, `for item in collection`)
- [x] Infinite loops (`for {}` with break)
- [x] Pattern matching / switch expressions
- [x] Error recovery (continue past errors)
- [x] `->` token for return types
- [x] Function calls (`print(42)`)

### AST
- [x] Enum declaration factory function
- [x] Complete type constructors (arrays, functions)
- [x] Proper node destruction (`destroy_node`, `destroy_program`)

---

## Code Generation

### LLVM Backend
- [x] Function parameter binding (`LLVMGetParam`)
- [x] Proper return types (void, int, i32, f64, f32, etc.)
- [x] Comparison operators (`<`, `>`, `==`, etc.)
- [x] Logical operators (`&&`, `||`, `!`)
- [x] Boolean literals (`true`/`false`)
- [x] Function calls (`LLVMBuildCall`)
- [x] Control flow - if/else with branches
- [x] Odin-style `for` loops (range, condition, infinite)
- [x] `break` and `continue`
- [ ] Phi nodes (for SSA form)
- [x] Local variables (load after alloca)
- [x] Global variables / constants (`x = 42`, `x: int = 10`)
- [x] String literals (basic printf support)
- [x] Array literals and indexing
- [x] Pointer types (`^type` for int, float, etc.)
- [x] Address-of operator (`&var`)
- [x] Struct member access
- [x] Enum variant access (`TokenType.Int`)

---

## Type System
- [x] Type checking (basic)
- [ ] Type inference (basic)
- [ ] Error messages for type mismatches (with line numbers)
- [ ] Integer/float promotion

---

## Standard Library / Builtins
- [x] `print` / `println` builtins
- [x] `printf` style formatting (`%d`, `%f`, `%s`, `%%`, escape sequences)
- [x] Basic I/O (`input`, `read_line`) - uses `scanf("%4095[^\n]")`

---

## CLI / Tooling
- [x] Help command (`acorn --help`)
- [x] Version command (`acorn --version`)
- [x] Debug/verbose flags (`--verbose`, `-vv`)
- [x] Error codes (non-zero on failure)
- [x] Proper error formatting with colors

---

## LLVM Backend Enhancements
- [ ] Proper target triple (`llvm::sys::getProcessTriple()`)
- [ ] Optimization passes (via `LLVMPassManager`)
- [ ] JIT execution (for `acorn run`)
- [ ] Remove dependency on `/tmp/acorn_linker`
- [x] Module verification before output
- [x] Assembly output option (`-S`)
- [x] Object file output (`-c`)
- [x] Input via `scanf` (avoids need for `LLVMGetNamedGlobal` to access stdin)

---

## Testing & Stability
- [x] Test suite (lexer tests, parser tests, codegen tests)
- [ ] Error recovery tests
- [ ] Standard library tests
- [ ] Cross-platform testing

---

## Documentation
- [ ] Language specification
- [ ] Standard library documentation
- [ ] Tool usage documentation

---

## Nice-to-Have for 1.0
- [x] Formatter (`acorn fmt`) - basic implementation exists
- [ ] LSP basics (for IDE support)
- [ ] REPL mode
- [ ] Package manager (basic)

---

**Minimum for usable 1.0**: DONE - Lexer fixes, Parser completeness, working LLVM codegen with functions/if/for/return, `print` builtin, CLI polish.
