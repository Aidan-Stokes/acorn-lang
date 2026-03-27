package main

import "./cli"
import "./common"
import "./lexer"
import "core:fmt"
import "core:mem"
import "core:os"

TRACK_ALLOCATOR :: #config(TRACK_ALLOCATOR, false)

VERSION :: "1.0.0"

print_help :: proc() {
    fmt.println("Acorn compiler")
    fmt.println("Usage: acorn <command> [options] [file]")
    fmt.println("Commands:")
    fmt.println("  build <file>   Compile an Acorn file")
    fmt.println("  run <file>     Run an Acorn file")
    fmt.println("  fmt <file>     Format an Acorn file")
    fmt.println("  check <file>   Type check an Acorn file")
    fmt.println("Options:")
    fmt.println("  -o <file>      Set output file")
    fmt.println("  -S             Output assembly (.s file)")
    fmt.println("  -c             Output object file (.o file)")
    fmt.println("  -v, --verbose  Show compilation stages")
    fmt.println("  -h, --help     Show this help message")
    fmt.println("  --version      Show version information")
}

print_version :: proc() {
    fmt.printf("Acorn compiler version %s\n", VERSION)
}

main :: proc() {
    args := os.args
    if len(args) < 2 {
        print_help()
        return
    }

    cmd := ""
    filename := ""
    output_file := ""
    output_type := common.Output_Type.Executable
    verbose := false

    i := 1
    for i < len(args) {
        arg := args[i]
        if cmd == "" && (arg == "build" || arg == "run" || arg == "fmt" || arg == "check") {
            cmd = arg
            i += 1
        } else if arg == "-o" && i + 1 < len(args) {
            output_file = args[i + 1]
            i += 2
        } else if arg == "-S" {
            output_type = common.Output_Type.Assembly
            i += 1
        } else if arg == "-c" {
            output_type = common.Output_Type.Object
            i += 1
        } else if arg == "--verbose" || arg == "-vv" {
            verbose = true
            i += 1
        } else if arg == "-h" || arg == "--help" {
            print_help()
            return
        } else if arg == "--version" {
            print_version()
            return
        } else if cmd != "" && filename == "" {
            filename = arg
            i += 1
        } else {
            i += 1
        }
    }

    if cmd == "" {
        print_help()
        return
    }

    when TRACK_ALLOCATOR {
        @(static) tracker: mem.Tracking_Allocator
        mem.tracking_allocator_init(&tracker, context.allocator)
        context.allocator = mem.tracking_allocator(&tracker)
        cli.set_allocator(mem.tracking_allocator(&tracker))
    }

    cli.set_verbose(verbose)

    switch cmd {
    case "build":
        if filename == "" {
            fmt.println("Error: No input file specified")
            os.exit(1)
        }
        cli.build(filename, output_file, common.Output_Type(output_type))
    case "run":
        if filename == "" {
            fmt.println("Error: No input file specified")
            os.exit(1)
        }
        cli.run(filename, output_file)
    case "fmt":
        if filename == "" {
            fmt.println("Error: No input file specified")
            os.exit(1)
        }
        cli.fmt_proc(filename)
    case "check":
        if filename == "" {
            fmt.println("Error: No input file specified")
            os.exit(1)
        }
        cli.check(filename)
    case:
        fmt.printf("Unknown command: %s\n", cmd)
        os.exit(1)
    }

    when TRACK_ALLOCATOR {
        if len(tracker.allocation_map) > 0 {
            fmt.println("\nMemory leaks detected:")
            for _, v in tracker.allocation_map {
                fmt.printf("  %v bytes at %p\n", v.size, v.memory)
            }
        }
        if len(tracker.bad_free_array) > 0 {
            fmt.println("\nBad frees detected:")
            for v in tracker.bad_free_array {
                fmt.printf("  %p\n", v.memory)
            }
        }
    }

    lexer.destroy_keywords()
}
