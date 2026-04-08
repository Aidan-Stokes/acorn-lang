# Acorn Programming Language

A simple, expressive programming language inspired by Odin and Rust, compiled to LLVM IR.

## Features

- **Clean syntax** with `<-` for assignment and `::` for declarations
- **Strong typing** with type inference
- **LLVM backend** for fast native code generation
- **Familiar constructs**: structs, enums, pattern matching, range-based loops

## Quick Start

### Build from Source

Requirements:
- [Odin](https://github.com/odin-lang/Odin) compiler
- LLVM (llvm-16 or later recommended)

```bash
# Build the compiler
odin build . -build-mode:exe -file

# Run an example
./acorn run examples/00_hello_world.acorn

# Or compile and run separately
./acorn build examples/00_hello_world.acorn -o hello
./hello
```

### Language Basics

```acorn
// Functions use :: syntax
import "core:fmt"

main :: fn() -> int {
    fmt.println("Hello, World!")
    return 0
}

// Variables with <-
x <- 42
y <- x + 10

// Structs
Point :: struct {
    x: int
    y: int
}

p <- Point{x: 10, y: 20}

// Loops
for i in 0..10 {
    fmt.println(i)
}

// Pattern matching
match value {
    Some(x) => fmt.println(x)
    None => fmt.println("nothing")
}
```

## Installation

### Pre-built Binaries
Download from the releases page.

### Build from Source
```bash
git clone https://github.com/Aidan-Stokes/acorn-lang.git
cd acorn
odin build . -build-mode:exe -file
sudo cp acorn /usr/local/bin/
```

## CLI Usage

```bash
# Compile
acorn build <file>           # Build executable
acorn build <file> -o out    # Custom output name
acorn build <file> -c        # Output object file (.o)
acorn build <file> -S        # Output assembly (.s)

# Run directly
acorn run <file>

# Type check only
acorn check <file>

# Format code
acorn fmt <file>
```

## Standard Library

Import modules with qualified access:

```acorn
import "core:fmt"

main :: fn() -> int {
    fmt.println("Hello!")  // Use fmt.println, not print
    return 0
}
```

### Available Modules
- `core:fmt` - Formatting (print, println, printf)
- `core:math` - Math constants and functions
- `core:arrays` - Array utilities
- `core:strings` - String operations
- `core:io` - I/O operations

### Import Variants

```acorn
// Basic - use qualified access
import "core:math"
fmt.println(math.PI)

// Selective - import specific symbols
import "core:math" { PI }
fmt.println(PI)

// Alias - rename module
import "core:math" as m
fmt.println(m.PI)

// Combined
import "core:math" { PI } as m
fmt.println(m.PI)
```

## Examples

See the `examples/` directory for working code:

| Example | Description |
|---------|-------------|
| `00_hello_world.acorn` | Basic function |
| `02_variables.acorn` | Variable assignment |
| `03_arithmetic.acorn` | Math operations |
| `07_if_else.acorn` | Conditionals |
| `08_for_range.acorn` | Range loops |
| `23_structs.acorn` | Struct declarations |
| `24_enums.acorn` | Enum types |
| `27_match.acorn` | Pattern matching |

Run all examples:
```bash
cd examples && ./run_all.sh
```

## Supported Types

| Type | Description |
|------|-------------|
| `int` | Default integer (u64) |
| `i32`, `i16`, `i8` | Signed integers |
| `uint`, `u32`, `u16`, `u8` | Unsigned integers |
| `f32`, `f64` | Floating point |
| `bool` | Boolean (true/false) |
| `char`, `rune` | Character (32-bit) |
| `string`, `str` | String |
| `[]T` | Dynamic arrays |

## Roadmap

See [ROADMAP.md](ROADMAP.md) for implementation status and planned features.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run examples to verify: `./acorn build examples/*.acorn`
5. Submit a pull request

## License

MIT License - see LICENSE file for details.