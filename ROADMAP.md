# Acorn 1.0 - Implementation Roadmap

## Recent Fixes (2026-04-09)

### New Type System (AST Refactoring)
- Created `ast/types_new.odin` with union-based type system
- Added `Type_New` union with proper variants: Primitive, Pointer, Array, Function, Struct, Enum, Generic, Named
- Added builder functions: `make_int_type()`, `make_pointer_type()`, etc.
- Added constraint checking: `check_constraint(t, .Integral)`
- Added migration helpers: `convert_from_old_type()`, `convert_from_type_info()`
- Added `new_type` field to Node for type information from type checker

### Unified Error System
- Created `common/errors.odin` with `Error_Kind` enum: Lexer, Parser, Type, Codegen, Import, Warning
- Added helper functions: `add_lexer_error()`, `add_parser_error()`, `add_type_error()`, etc.
- Added global error reporter lifecycle: `common.init()`/`common.destroy()`
- Updated type checker to use unified error system

### Forward-Declared Generic Functions
- Implemented `arrays.len()`, `arrays.first()`, `arrays.get()`, `arrays.last()` in codegen
- Converts to equivalent index expressions instead of generating undefined function calls

### String Functions
- Added `strings.to_upper()`, `strings.to_lower()`, `strings.trim()` to codegen
- All compile-time string functions work: `contains`, `starts_with`, `ends_with`, `index_of`

### JIT Execution
- Added `-J` flag for JIT execution via `lli`
- Added `run_jit()` function in codegen
- Passes optimization levels to JIT: `acorn run -J -O2 file.acorn`
- Falls back to compilation if JIT fails

### Optimization Levels
- Added `-O0`, `-O1`, `-O2`, `-O3` CLI flags
- Passed to LLVM's `llc` compiler via command line

---

## Recent Fixes (2026-04-08)

### fmt.print/fmt.println Implementation
- Removed builtin `print`/`println` - now only `fmt.print`/`fmt.println` work
- Updated codegen to handle `fmt.print()` and `fmt.println()` calls via `core:fmt` import
- Fixed printf stub conflict by creating proper varargs printf declaration
- fmt.acorn now uses forward declarations (no body) - codegen handles actual printing
- Works with strings, integers, floats, and booleans

### Array Operations Fix
- Fixed `len(arr)` to return proper array length
- Fixed array indexing `arr[i]` to work correctly
- Added `array_len` tracking in Var_Entry for type checker

## Recent Fixes (2026-04-01)

### Generic Type Support
- Added generic type map (`generic_type_map`) in codegen for type substitution
- Added `generic_params` field to `Fn_Info` struct for tracking generic parameters
- Generic struct declarations work: `Container<T> :: struct { value: T }`
- Generic function declarations work: `abs<T> :: fn(x: T) -> T`
- Added generic type resolution in `get_llvm_type` function
- Added generic functions to stdlib: arrays.acorn, strings.acorn, math.acorn, io.acorn, fmt.acorn
- Note: Generic function calls still have codegen issues causing segfaults

### Where Clause Constraints
- Added `WHERE` token and `ANDAND` (&&) token to lexer
- Parser can parse explicit generic syntax: `abs<int>(5)`
- Parser supports where clauses with multiple constraints: `where T: Comparable && T: Addable`
- Type checker validates 11 constraints: Equatable, Comparable, Addable, Subtractable, Multipliable, Divisible, Negatable, Showable, Integral, Floating, Byte_Equatable
- Updated stdlib with constraints: math.acorn, arrays.acorn, strings.acorn

### Type System Fixes
- Discovered and fixed type mismatch: `int` was i64 in get_llvm_type but i32 elsewhere
- Standardized all integer handling to use i32 consistently
- All 54 tests now pass (previously failing arithmetic tests)

### Type Naming Change
- Changed `u` to `uint` for unsigned integers (more descriptive)

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
import "core:fmt"

main :: fn() -> int {
    fmt.println("Hello, World!")
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

// Integer types: int (u64), uint, i32, i16, i8, u8, byte, u16, u32, u64, i64
// Float types: f32, f64
// Other: bool, char, rune, string

// Function calls (via core:fmt)
fmt.print("Hello, World!")
fmt.println("with newline")

// Control flow
if (x > 0) {
    fmt.println("positive")
} else {
    fmt.println("non-positive")
}

// Loops - Odin-style
for i in 0..10 {
    fmt.println(i)
}

for i in 0..10 by 2 {
    fmt.println(i)
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
fmt.println(arr[0])

// Float literals
pi <- 3.14159

// Character literals
c <- 'a'
newline <- '\n'

// Import statements (fully implemented)
import "core:fmt"                    // Qualified access: fmt.println
import "core:math" { PI }            // Selective: PI directly in scope
import "core:math" as m              // Alias: m.PI
import "core:math" { PI } as m       // Combined: selective + alias
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
- [x] Generic type parameters (`<T>` in functions and structs)
- [x] Where clause constraints (`where T: Constraint1 && T: Constraint2`)

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
- [x] `fmt.print` / `fmt.println` (via core:fmt import)
- [x] `printf` style formatting (`%d`, `%f`, `%s`, `%%`, escape sequences)
- [x] Basic I/O (`input`, `read_line`) - uses `scanf("%4095[^\n]")`
- [x] Basic stdlib modules (`core:math` with `PI` constant)
- [x] Generic array utilities (`len<T>`, `get<T>`, `set<T>`, `first<T>`, etc.)
- [x] Generic math utilities (`abs<T>`, `min<T>`, `max<T>`, `clamp<T>`)
- [x] String utilities (`len`, `contains`, `split`, `join`, etc.)
- [x] I/O utilities (`read_file`, `write_file`, `get_env`, etc.)
- [x] Formatting utilities (`printf`, `to_string`, `format`)

---

## Module System
- [x] Import statement parsing (all syntax variants)
- [x] Module resolution (`core:*` → stdlib, `libname:*` → lib)
- [x] Qualified access (`fmt.println`, `math.PI`)
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
- [x] Optimization levels (`-O0`, `-O1`, `-O2`, `-O3`)
- [x] JIT execution (`-J` flag)

---

## LLVM Backend Enhancements
- [ ] Proper target triple (`llvm::sys::getProcessTriple()`)
- [x] Optimization levels via `llc -On`
- [x] JIT execution (via `lli`)
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