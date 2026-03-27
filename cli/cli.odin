package cli

import "core:fmt"
import "core:mem"
import "core:os"
import old "core:os/old"

import "../codegen"
import "../common"
import "../lexer"
import "../parser"
import "../typecheck"

current_allocator: mem.Allocator
is_verbose: bool

set_allocator :: proc(alloc: mem.Allocator) {
	current_allocator = alloc
}

get_allocator :: proc() -> mem.Allocator {
	if current_allocator.data == nil {
		return context.allocator
	}
	return current_allocator
}

set_verbose :: proc(verbose: bool) {
	is_verbose = verbose
}

get_verbose :: proc() -> bool {
	return is_verbose
}

set_backend :: proc(backend: string) {
	if backend != "llvm" {
		fmt.printf("Unknown backend: %s, using llvm\n", backend)
	}
}

build :: proc(filename: string, user_output_file: string = "", output_type: common.Output_Type = .Executable) {
	alloc := get_allocator()

	output_file := user_output_file
	if output_file == "" {
		#partial switch output_type {
		case .Executable:
			output_file = "acorn_out"
		case .Object:
			output_file = "acorn_out.o"
		case .Assembly:
			output_file = "acorn_out.s"
		}
	}

	if is_verbose {
		common.colorf(.Blue, "Compiling: %s\n", filename)
	}

	success := codegen.compile_llvm(filename, output_file, alloc, is_verbose, output_type)

	if !success {
		common.print_error("Build failed", 0, 0)
		os.exit(1)
	}

	if is_verbose {
		common.colorf(.Green, "Output: %s\n", output_file)
	} else {
		fmt.println("Output:", output_file)
	}
}

run :: proc(filename: string, user_output_file: string = "") {
	alloc := get_allocator()

	output_file := user_output_file
	if output_file == "" {
		output_file = "acorn_temp_run"
	}

	if is_verbose {
		common.colorf(.Blue, "Compiling: %s\n", filename)
	}

	success := codegen.compile_llvm(filename, output_file, alloc, is_verbose)

	if !success {
		common.print_error("Compilation failed", 0, 0)
		os.exit(1)
	}

	if is_verbose {
		common.colorf(.Blue, "Running: %s\n", output_file)
	}

	result := old.execvp(output_file, []string{output_file})

	os.remove(output_file)

	if result != nil {
		os.exit(1)
	}
}

	fmt_proc :: proc(filename: string) {
	if is_verbose {
		common.colorf(.Blue, "Formatting: %s\n", filename)
	}

	data, err := os.read_entire_file_from_path(filename, context.allocator)
	if err != nil {
		common.print_error(fmt.tprintf("Could not read file: %s", filename), 0, 0)
		os.exit(1)
	}
	defer delete(data)

	source := string(data)
	l := lexer.init(source)
	tokens := lexer.scan(&l)
	lexer.destroy_tokens(&tokens)

	common.print_success("Formatted file (no changes - formatter not yet implemented)")
}

check :: proc(filename: string) {
	if is_verbose {
		common.colorf(.Blue, "Checking: %s\n", filename)
	}

	data, err := os.read_entire_file_from_path(filename, context.allocator)
	if err != nil {
		common.print_error(fmt.tprintf("Could not read file: %s", filename), 0, 0)
		os.exit(1)
	}
	defer delete(data)

	alloc := get_allocator()
	source := string(data)

	if is_verbose {
		common.colorf(.Yellow, "  Lexing...\n")
	}
	l := lexer.init(source)
	tokens := lexer.scan(&l)

	if is_verbose {
		common.colorf(.Yellow, "  Parsing...\n")
	}
	prog := parser.parse(source, alloc)
	lexer.destroy_tokens(&tokens)

	if parser.has_errors() {
		parser.print_errors()
		os.exit(1)
	}

	if is_verbose {
		common.colorf(.Yellow, "  Type checking...\n")
	}
	if !typecheck.check_program(prog) {
		typecheck.print_errors()
		os.exit(1)
	}

	common.print_success("Type check passed")
}
