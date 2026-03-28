package imports

import "core:fmt"
import "core:os"
import "core:strings"

visited_modules: map[string]bool
import_errors: [dynamic]string
verbose_mode: bool

init_imports :: proc(verbose: bool) {
	clear(&visited_modules)
	clear(&import_errors)
	verbose_mode = verbose
}

destroy_imports :: proc() {
	delete(visited_modules)
	delete(import_errors)
}

is_visited :: proc(path: string) -> bool {
	return visited_modules[path]
}

mark_visited :: proc(path: string) {
	visited_modules[path] = true
}

get_errors :: proc() -> []string {
	return import_errors[:]
}

add_error :: proc(msg: string) {
	append(&import_errors, msg)
}

resolve_module :: proc(module_path: string, current_file: string) -> (string, bool) {
	if strings.has_prefix(module_path, "core:") {
		module_name := strings.trim_prefix(module_path, "core:")
		resolved := resolve_stdlib_module(module_name, current_file)
		if resolved != "" {
			return resolved, true
		}
	} else if strings.has_prefix(module_path, "lib:") {
		module_name := strings.trim_prefix(module_path, "lib:")
		resolved := resolve_lib_module(module_name, current_file)
		if resolved != "" {
			return resolved, true
		}
	} else {
		resolved := resolve_local_module(module_path, current_file)
		if resolved != "" {
			return resolved, true
		}
	}
	add_error(fmt.tprintf("Cannot find module: %s", module_path))
	return "", false
}

resolve_stdlib_module :: proc(module_name: string, current_file: string) -> string {
	parts := []string{"stdlib/core/", module_name, ".acorn"}
	path := strings.concatenate(parts)
	if file_exists(path) {
		if verbose_mode {
			fmt.printf("Resolved '%s' to '%s'\n", module_name, path)
		}
		return path
	}

	parts = []string{"./stdlib/core/", module_name, ".acorn"}
	path = strings.concatenate(parts)
	if file_exists(path) {
		if verbose_mode {
			fmt.printf("Resolved '%s' to '%s'\n", module_name, path)
		}
		return path
	}

	parts = []string{"../stdlib/core/", module_name, ".acorn"}
	path = strings.concatenate(parts)
	if file_exists(path) {
		if verbose_mode {
			fmt.printf("Resolved '%s' to '%s'\n", module_name, path)
		}
		return path
	}

	parts = []string{"./acorn_stdlib/core/", module_name, ".acorn"}
	path = strings.concatenate(parts)
	if file_exists(path) {
		if verbose_mode {
			fmt.printf("Resolved '%s' to '%s'\n", module_name, path)
		}
		return path
	}

	stdlib_env := os.get_env_alloc("ACORN_STDLIB_PATH", context.allocator)
	if len(stdlib_env) > 0 {
		parts = []string{stdlib_env, "/core/", module_name, ".acorn"}
		path = strings.concatenate(parts)
		if file_exists(path) {
			if verbose_mode {
				fmt.printf("Resolved '%s' to '%s'\n", module_name, path)
			}
			return path
		}
	}

	return ""
}

resolve_lib_module :: proc(module_name: string, current_file: string) -> string {
	parts := []string{"lib/", module_name, ".acorn"}
	path := strings.concatenate(parts)
	if file_exists(path) {
		if verbose_mode {
			fmt.printf("Resolved '%s' to '%s'\n", module_name, path)
		}
		return path
	}

	parts = []string{"./lib/", module_name, ".acorn"}
	path = strings.concatenate(parts)
	if file_exists(path) {
		if verbose_mode {
			fmt.printf("Resolved '%s' to '%s'\n", module_name, path)
		}
		return path
	}

	parts = []string{"../lib/", module_name, ".acorn"}
	path = strings.concatenate(parts)
	if file_exists(path) {
		if verbose_mode {
			fmt.printf("Resolved '%s' to '%s'\n", module_name, path)
		}
		return path
	}

	lib_env := os.get_env_alloc("ACORN_LIB_PATH", context.allocator)
	if len(lib_env) > 0 {
		parts = []string{lib_env, "/", module_name, ".acorn"}
		path = strings.concatenate(parts)
		if file_exists(path) {
			if verbose_mode {
				fmt.printf("Resolved '%s' to '%s'\n", module_name, path)
			}
			return path
		}
	}

	return ""
}

resolve_local_module :: proc(module_path: string, current_file: string) -> string {
	if file_exists(module_path) {
		return module_path
	}

	current_dir := get_directory(current_file)
	parts := []string{current_dir, "/", module_path}
	resolved := strings.concatenate(parts)
	if file_exists(resolved) {
		return resolved
	}

	return ""
}

get_directory :: proc(filepath: string) -> string {
	for i := len(filepath) - 1; i >= 0; i -= 1 {
		if filepath[i] == '/' || filepath[i] == '\\' {
			return filepath[:i]
		}
	}
	return "."
}

file_exists :: proc(path: string) -> bool {
	return os.exists(path)
}
