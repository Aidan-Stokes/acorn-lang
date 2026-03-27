package common

import "core:fmt"

Output_Type :: enum {
    Executable,
    Object,
    Assembly,
}

Color :: enum {
    Reset,
    Bold,
    Red,
    Green,
    Yellow,
    Blue,
    White,
}

color_code :: proc(c: Color) -> string {
    switch c {
    case .Reset:
        return "\x1b[0m"
    case .Bold:
        return "\x1b[1m"
    case .Red:
        return "\x1b[31m"
    case .Green:
        return "\x1b[32m"
    case .Yellow:
        return "\x1b[33m"
    case .Blue:
        return "\x1b[34m"
    case .White:
        return "\x1b[37m"
    }
    return color_code(.Reset)
}

colorf :: proc(color: Color, format: string, args: ..any) {
    fmt.eprintf("%s", color_code(color))
    fmt.eprintf(format, ..args)
    fmt.eprintf("%s", color_code(.Reset))
}

print_error :: proc(message: string, line: int, column: int) {
    if line > 0 {
        colorf(.Red, "Error at line %d, column %d: %s\n", line, column, message)
    } else {
        colorf(.Red, "Error: %s\n", message)
    }
}

print_fatal :: proc(message: string) {
    colorf(.Bold + .Red, "Fatal: %s\n", message)
}

print_warning :: proc(message: string) {
    colorf(.Yellow, "Warning: %s\n", message)
}

print_info :: proc(message: string) {
    colorf(.White, "Info: %s\n", message)
}

print_debug :: proc(message: string) {
    colorf(.Blue, "Debug: %s\n", message)
}

print_success :: proc(message: string) {
    colorf(.Green, "Success: %s\n", message)
}
