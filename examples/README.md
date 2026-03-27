# Acorn Language Examples

This directory contains example programs demonstrating Acorn language features.

## Running Examples

```bash
# Run all examples
./run_all.sh

# Run a single example
../acorn run 00_hello_world.acorn
```

## Example List

| File | Feature |
|------|---------|
| `00_hello_world.acorn` | Basic function definition |
| `01_fn_keyword.acorn` | Odin-style `::` syntax |
| `02_variables.acorn` | Variable assignment (`<-`) |
| `03_arithmetic.acorn` | Arithmetic operators |
| `04_comparison.acorn` | Comparison operators |
| `05_logical.acorn` | Logical operators (`&&`, `||`, `!`) |
| `06_booleans.acorn` | Boolean literals |
| `07_if_else.acorn` | If/else statements |
| `08_for_range.acorn` | Range-based for loop (`for i in 0..n`) |
| `09_for_range_by.acorn` | Range with step (`by`) |
| `10_for_while.acorn` | While loop (`for cond`) |
| `11_for_infinite.acorn` | Infinite loop (`for {}`) |
| `12_break_continue.acorn` | `break` and `continue` |
| `13_arrays.acorn` | Array literals |
| `14_typed_arrays.acorn` | Typed array declarations |
| `15_print.acorn` | `print` and `println` |
| `16_floats.acorn` | Float literals |
| `17_pointers.acorn` | Pointer types (`^`, `&`, dereference) |
| `18_types.acorn` | Basic types (int, float, bool, str, etc.) |
| `19_character_literals.acorn` | Character literals (`'a'`, `'\n'`) |
| `20_scientific_notation.acorn` | Scientific notation (`1e10`) |
| `21_printf.acorn` | `printf` formatting |
| `22_input_output.acorn` | `read_line()` and `input()` |
| `23_structs.acorn` | Struct declarations and literals |

## Features

### Working Features
- ✅ Function definitions (`name :: fn() -> type { }`)
- ✅ Variable assignment with `<-`
- ✅ Types: `int`, `u`, `i32`, `i16`, `i8`, `u8`, `byte`, `u16`, `u32`, `u64`, `i64`, `f32`, `f64`, `bool`, `char`, `rune`, `string`
- ✅ Arithmetic: `+`, `-`, `*`, `/`, `%`
- ✅ Comparison: `==`, `!=`, `<`, `<=`, `>`, `>=`
- ✅ Logical: `&&`, `||`, `!`
- ✅ Booleans: `true`, `false`
- ✅ If/else statements
- ✅ For loops: range (`for i in 0..n`), while (`for cond`), infinite (`for {}`)
- ✅ `break` and `continue`
- ✅ Arrays: `[1, 2, 3]`
- ✅ Array indexing: `arr[0]`
- ✅ Typed arrays: `arr: []int <- [1, 2, 3]`
- ✅ Pointer types: `^type`, address-of `&var`, dereference `ptr^` (works with int, float, etc.)
- ✅ `print` and `println` builtins
- ✅ `printf` with formatting (`%d`, `%f`, `%s`, `%%`)
- ✅ Float literals and scientific notation (`1e10`, `3.14e-5`)
- ✅ Character literals (`'a'`, `'\n'`, `'\x41'`)
- ✅ String escape sequences (`\n`, `\t`, `\"`, `\\`, `\'`, `\0`, `\xNN`)
- ✅ `read_line()` and `input()` for user input
- ✅ Struct declarations (`Point :: struct { x: int, y: int }`)
- ✅ Struct literals (`Point{x: 10, y: 20}`)

### Not Yet Implemented
- ⏳ Block comments (`/* */`)
- ⏳ Enum declarations
- ⏳ Pattern matching
- ⏳ Import statements
- ⏳ Global variables
- ⏳ Local struct declarations (structs inside functions)
