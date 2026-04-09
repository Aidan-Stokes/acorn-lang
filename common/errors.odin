package common

import "core:fmt"

Error_Kind :: enum {
    None,
    Lexer,
    Parser,
    Type,
    Codegen,
    Import,
    Warning,
}

Error :: struct {
    message: string,
    line:    int,
    column:  int,
    kind:    Error_Kind,
}

// Enhanced error reporter with kind support
Error_Reporter :: struct {
    errors:        [dynamic]Error,
    warnings:      [dynamic]Error,
    error_count:   int,
    warning_count: int,
}

init_reporter :: proc(reporter: ^Error_Reporter) {
    reporter.errors = make([dynamic]Error, 0, 8)
    reporter.warnings = make([dynamic]Error, 0, 8)
    reporter.error_count = 0
    reporter.warning_count = 0
}

destroy_reporter :: proc(reporter: ^Error_Reporter) {
    delete(reporter.errors)
    delete(reporter.warnings)
}

add_error_with_kind :: proc(reporter: ^Error_Reporter, kind: Error_Kind, message: string, line: int, column: int) {
    err := Error{message = message, line = line, column = column, kind = kind}
    append(&reporter.errors, err)
    reporter.error_count += 1
}

add_error :: proc(message: string, line: int, column: int) {
    // Legacy - add as parser error
    add_error_with_kind(&global_reporter, .Parser, message, line, column)
}

add_warning :: proc(message: string, line: int, column: int) {
    warn := Error{message = message, line = line, column = column, kind = .Warning}
    append(&global_reporter.warnings, warn)
    global_reporter.warning_count += 1
}

has_errors :: proc() -> bool {
    return len(global_reporter.errors) > 0
}

error_count :: proc() -> int {
    return global_reporter.error_count
}

warning_count :: proc() -> int {
    return global_reporter.warning_count
}

get_errors :: proc() -> []Error {
    return global_reporter.errors[:]
}

clear_errors :: proc() {
    clear(&global_reporter.errors)
    clear(&global_reporter.warnings)
    global_reporter.error_count = 0
    global_reporter.warning_count = 0
}

print_error_at :: proc(message: string, line: int, column: int) {
    if line > 0 {
        fmt.printf("\033[31mError\033[0m at line %d, column %d: %s\n", line, column, message)
    } else {
        fmt.printf("\033[31mError\033[0m: %s\n", message)
    }
}

print_warning_at :: proc(message: string, line: int, column: int) {
    if line > 0 {
        fmt.printf("\033[33mWarning\033[0m at line %d, column %d: %s\n", line, column, message)
    } else {
        fmt.printf("\033[33mWarning\033[0m: %s\n", message)
    }
}

print_errors :: proc() {
    // Print warnings first
    for warn in global_reporter.warnings {
        print_warning_at(warn.message, warn.line, warn.column)
    }
    
    // Then errors
    for err in global_reporter.errors {
        kind_str := ""
        #partial switch err.kind {
        case .Lexer: kind_str = "Lexer Error: "
        case .Parser: kind_str = "Parser Error: "
        case .Type: kind_str = "Type Error: "
        case .Codegen: kind_str = "Codegen Error: "
        case .Import: kind_str = "Import Error: "
        case: kind_str = "Error: "
        }
        msg := fmt.tprintf("%s%s", kind_str, err.message)
        print_error_at(msg, err.line, err.column)
    }
}

// Helper functions for specific error kinds
add_lexer_error :: proc(message: string, line: int, column: int) {
    add_error_with_kind(&global_reporter, .Lexer, message, line, column)
}

add_parser_error :: proc(message: string, line: int, column: int) {
    add_error_with_kind(&global_reporter, .Parser, message, line, column)
}

add_type_error :: proc(message: string, line: int, column: int) {
    add_error_with_kind(&global_reporter, .Type, message, line, column)
}

add_codegen_error :: proc(message: string, line: int, column: int) {
    add_error_with_kind(&global_reporter, .Codegen, message, line, column)
}

add_import_error :: proc(message: string, line: int, column: int) {
    add_error_with_kind(&global_reporter, .Import, message, line, column)
}