# Acorn 1.0 - Implementation Roadmap

## Recent Fixes (2026-03-26)

### Import Statements (Fully Implemented)
- All import syntax variants now work with full module resolution and codegen
- **Basic import**: `import "core:math"` - All module symbols available with qualified access
- **Selective import**: `import "core:math" { PI }` - Only specified symbols added to direct scope
- **Alias import**: `import "core:math" as m` - Module registered with alias for `m.PI` access
- **Combined**: `import "core:math" { PI } as m` - Both selective and alias together

**Implementation details:**
- Added `AS` token for `as` keyword in lexer
- Added `selective_imports` and `import_alias` fields to AST `Import_Stmt`
- Added `imports/` module with `resolve_module()` for path resolution
- Module resolution: `"core:*"` → `./stdlib/core/*/` (via `$ACORN_STDLIB_PATH`)
- Module resolution: `"libname:*"` → `./lib/libname/*/` (via `$ACORN_LIB_PATH`)
- Added `Module_Info`, `module_registry`, `module_aliases` in type checker
- Added `.Module` to `Type_Kind` enum for tracking module type
- Updated `Member_Expr` in type checker to handle module-qualified access (`m.PI`)
- Updated `process_imports()` in codegen to handle all syntax variants
- Updated `Member_Expr` codegen to look up module symbols in `global_consts`
- Circular imports are detected and prevented via `is_visited` tracking
- All 30 existing examples still compile correctly

### Positional Struct Literals
- Added support for `Point{10, 20}` instead of `Point{x: 10, y: 20}`
- Both named and positional syntax can be mixed: `Point{10, y: 20}`
- Positional arguments are assigned by index in the struct definition
- Added `parse_struct_literal_fields` helper and `peek_next_kind` procedure
- Updated all three struct literal parsing locations: assignment, var decl, var/const decl

### Fixed is_numeric Type Checker Bug
- `is_numeric` function now correctly handles all integer type names (int, i32, u64, etc.)
- Struct field arithmetic now works: `p.x + p.y` where x and y are int fields
- Previously, accessing struct fields and using them in arithmetic would fail type checking

### Parser Segmentation Fault Fix
- Fixed crash when parsing invalid inputs like `main :: fn() -> int { print(42; return 0 }`
- Added EOF checks to prevent infinite loops in all parsing loops
- Fixed: `parse_call`, `parse_primary` (array literals), `parse_match_stmt`, `parse_assignment`, `parse_var_decl`, `parse_var_or_const_decl`
- Now properly reports errors and exits gracefully instead of crashing

### Improved Error Recovery
- Added smarter error reporting for missing commas in:
  - Function call arguments: `print(42 43)` → "Expected ',' but got INT"
  - Array literals: `[1, 2 3]` → "Expected ',' but got INT"
  - Struct literals: `Point{x: 1 y: 2}` → "Expected ',' but got IDENT"
- All 66+ tests pass including comprehensive error recovery tests

### Type Checker Improvements
- Fixed arithmetic operators rejecting string + number: `x <- "hello" + 42` now caught as type error
- Added return type checking: functions now verify return statement types match declaration
- Added `current_fn_return_type` tracking in type checker
- Error messages now properly report mismatched types

### Removed /tmp/acorn_linker Dependency
- Now calls `llc` and `clang` directly using `llvm.system()`
- No external script required - compiler is fully self-contained
- Uses `system()` which doesn't replace the process, allowing compilation to continue
- Added `system()` function to LLVM bindings via libc

## Previous Fixes (2026-03-24)

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

### Global Constants
- Constants can be declared at top level: `x = 42`, `x: int = 10`, `x: f64 = 3.14`
- Multiple constants in sequence work: `x = 10\ny = 5\nprint(x + y)`

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
    print("Hello, World!")
    return 0
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

// Integer types: int (u64), u (uint), i32, i16, i8, u8, byte, u16, u32, u64, i64
// Float types: f32, f64
// Other: bool, char, rune, string

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
if (x == 5) { break }
if (x == 3) { continue }

// Boolean literals
flag <- true

// Array literals
arr <- [1, 2, 3]
print(arr[0])

// Float literals
pi <- 3.14159

// Character literals
c <- 'a'
newline <- '\n'

// Import statements (fully implemented)
import "core:math"                    // Qualified access: math.PI
import "core:math" { PI }            // Selective: PI directly in scope
import "core:math" as m              // Alias: m.PI
import "core:math" { PI } as m      // Combined: selective + alias
```

### Planned Syntax Extensions

```acorn
// Pipes (function composition) - future
result <- value |> transform |> process

// Iterating over arrays - future
for item, index in arr {
    print(index, item)
}

// Function types - future
callback: fn(int, int) -> int

// Generics - future
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
- [x] `AS` token for import aliases

### Parser
- [x] Enum declarations (`enum Color { Red, Green, Blue }`)
- [x] Import statements (fully implemented with resolution)
- [x] Struct literals (`Point{x: 1, y: 2}`)
- [x] Positional struct literals (`Point{10, 20}`)
- [x] Struct declarations (`Point :: struct { x: int, y: int }`)
- [x] Struct member access (`p.x`)
- [x] Float literals (basic decimal)
- [x] Type annotations on variables (`x: int <- expr`, `arr: []int <- [1, 2, 3]`)
- [x] Break/continue statements
- [x] Odin-style `for` loops (`for x in range`, `for condition`, `for item in collection`)
- [x] Infinite loops (`for {}` with break)
- [x] Pattern matching / switch expressions
- [x] Error recovery (continue past errors, no segfaults)
- [x] `->` token for return types
- [x] Function calls (`print(42)`)

### AST
- [x] Enum declaration factory function
- [x] Complete type constructors (arrays, functions)
- [x] Proper node destruction (`destroy_node`, `destroy_program`)
- [x] Import statement fields (`selective_imports`, `import_alias`)
- [x] Module type kind (`.Module` in `Type_Kind`)

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
- [x] Import statement codegen (module-qualified member access)

---

## Type System
- [x] Type checking (basic)
- [x] Type inference (basic)
- [x] Error messages for type mismatches
- [ ] Integer/float promotion

---

## Standard Library / Builtins
- [x] `print` / `println` builtins
- [x] `printf` style formatting (`%d`, `%f`, `%s`, `%%`, escape sequences)
- [x] Basic I/O (`input`, `read_line`) - uses `scanf("%4095[^\n]")`
- [x] Basic stdlib modules (`core:math` with `PI` constant)

---

## Module System
- [x] Import statement parsing (all syntax variants)
- [x] Module resolution (`core:*` → stdlib, `libname:*` → lib)
- [x] Qualified access (`math.PI`)
- [x] Selective imports (`import "mod" { symbol }`)
- [x] Import aliases (`import "mod" as alias`)
- [x] Circular import detection
- [ ] Module symbol export declarations
- [ ] Standard library (more modules needed)

---

## CLI / Tooling
- [x] Help command (`acorn --help`)
- [x] Version command (`acorn --version`)
- [x] Debug/verbose flags (`--verbose`, `-vv`)
- [x] Error codes (non-zero on failure)
- [x] Proper error formatting with colors
- [x] Build script (`./build.sh`)
- [x] Test script (`./test.sh`)
- [x] GitHub Actions CI workflow

---

## LLVM Backend Enhancements
- [ ] Proper target triple (`llvm::sys::getProcessTriple()`)
- [ ] Optimization passes (via `LLVMPassManager`)
- [ ] JIT execution (for `acorn run`)
- [x] Self-contained compilation (no external linker script)
- [x] Module verification before output
- [x] Assembly output option (`-S`)
- [x] Object file output (`-c`)
- [x] Input via `scanf` (avoids need for `LLVMGetNamedGlobal` to access stdin)

---

## Testing & Stability
- [x] Test suite (30 examples + test.sh runner)
- [x] Error recovery tests
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

**v1.0.0 Status**: READY FOR RELEASE

All core language features implemented:
- Functions, structs, enums, pattern matching
- Type checking with error messages
- LLVM backend for native code generation
- Import system with module resolution
- CLI tools (build, run, check, fmt)
- 30+ example programs
- Cross-platform build scripts
- GitHub Actions CI
