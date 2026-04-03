package tests

import "core:fmt"
import "core:os"
import "core:strings"
import "core:c"

foreign import libc "system:c"

foreign libc {
	@(link_name="system")
	c_system :: proc(cmd: cstring) -> c.int ---
}

Test_Result :: struct {
	name:        string,
	passed:      bool,
	expected:    string,
	actual:      string,
	expect_err: bool,
}

run_single_test :: proc(name: string, code: string, expected: string, expect_err: bool) -> Test_Result {
	result := Test_Result {
		name        = name,
		passed      = false,
		expected    = expected,
		expect_err  = expect_err,
	}

	code_file := "/tmp/test_code.acorn"
	_ = os.write_entire_file_from_string(code_file, code)

	check_cmd := "cd /home/aidans/Odin/acorn && ./acorn check /tmp/test_code.acorn >/dev/null 2>&1"
	cmd_cstr := strings.clone_to_cstring(check_cmd)
	check_result := int(c_system(cmd_cstr))
	delete(cmd_cstr)

	build_cmd := "cd /home/aidans/Odin/acorn && ./acorn build /tmp/test_code.acorn -o /tmp/test_out >/dev/null 2>&1"
	cmd_cstr = strings.clone_to_cstring(build_cmd)
	build_result := int(c_system(cmd_cstr))
	delete(cmd_cstr)

	if expect_err {
		if check_result != 0 {
			result.passed = true
		} else {
			result.actual = "no error"
		}
	} else {
		if check_result != 0 || build_result != 0 {
			result.actual = "build failed"
		} else {
			run_cmd := "/tmp/test_out >/tmp/test_output.txt 2>&1"
			cmd_cstr = strings.clone_to_cstring(run_cmd)
			run_result := int(c_system(cmd_cstr))
			delete(cmd_cstr)
			if run_result == 0 {
				data, err := os.read_entire_file_from_path("/tmp/test_output.txt", context.allocator)
				if err == nil {
					expected_bytes := transmute([]u8)expected
					i := 0
					j := 0
					for i < len(data) && j < len(expected_bytes) {
						if data[i] == expected_bytes[j] {
							j += 1
						} else if data[i] != '\n' && data[i] != '\r' {
							break
						}
						i += 1
					}
					if j == len(expected_bytes) {
						result.passed = true
					}
				}
			}
		}
	}

	return result
}

run_all_tests :: proc() -> (passed: int, failed: int) {
	passed = 0
	failed = 0

	tests := [?]struct {
		name:        string,
		code:        string,
		expected:    string,
		expect_err: bool,
	} {
		{"hello_world", "main :: fn() -> int { print(42); return 0 }", "42", false},
		{"simple_print", "main :: fn() -> int { print(\"Hello\"); return 0 }", "Hello", false},
		{"simple_assign", "main :: fn() -> int { x <- 10; print(x); return 0 }", "10", false},
		{"typed_int", "main :: fn() -> int { x: int <- 42; print(x); return 0 }", "42", false},
		{"add", "main :: fn() -> int { a <- 10; b <- 3; print(a + b); return 0 }", "13", false},
		{"subtract", "main :: fn() -> int { a <- 10; b <- 3; print(a - b); return 0 }", "7", false},
		{"multiply", "main :: fn() -> int { a <- 10; b <- 3; print(a * b); return 0 }", "30", false},
		{"divide", "main :: fn() -> int { a <- 10; b <- 3; print(a / b); return 0 }", "3", false},
		{"equal_true", "main :: fn() -> int { print(5 == 5); return 0 }", "1", false},
		{"greater_than_true", "main :: fn() -> int { print(5 > 3); return 0 }", "1", false},
		{"and_true", "main :: fn() -> int { print(true && true); return 0 }", "1", false},
		{"or_true", "main :: fn() -> int { print(true || false); return 0 }", "1", false},
		{"if_true", "main :: fn() -> int { if (true) { print(\"yes\") }; return 0 }", "yes", false},
		{"if_else_false", "main :: fn() -> int { if (false) { print(\"yes\") } else { print(\"no\") }; return 0 }", "no", false},
		{"for_range", "main :: fn() -> int { for i in 0..3 { print(i) }; return 0 }", "0123", false},
		{"for_while", "main :: fn() -> int { i <- 0; for i < 3 { print(i); i <- i + 1 }; return 0 }", "012", false},
		{"array_literal", "main :: fn() -> int { arr <- [1, 2, 3]; print(arr[0]); return 0 }", "1", false},
		{"float_literal", "main :: fn() -> int { x <- 3.14; print(x); return 0 }", "3", false},
		{"type_error_string_to_int", "main :: fn() -> int { x: int <- \"hello\"; return 0 }", "", true},
		{"type_error_arith_strings", "main :: fn() -> int { x <- \"a\" + \"b\"; return 0 }", "", true},
		{"struct_decl", "Point :: struct { x: int, y: int }\nmain :: fn() -> int { print(\"Point\"); return 0 }", "Point", false},
		{"enum_decl", "main :: fn() -> int { Color :: enum { Red, Green, Blue }; print(\"Enum\"); return 0 }", "Enum", false},
		{"pointer_address_of", "main :: fn() -> int { x <- 42; y <- &x; print(y^); return 0 }", "42", false},
		{"const_simple", "x = 42\nmain :: fn() -> int { print(x); return 0 }", "42", false},
		{"global_var_int", "x <- 42\nmain :: fn() -> int { print(x); return 0 }", "42", false},
	}

	fmt.println("========================================")
	fmt.println("Acorn Compiler Test Suite")
	fmt.println("========================================")
	fmt.println("")

	for test in tests {
		result := run_single_test(test.name, test.code, test.expected, test.expect_err)
		if result.passed {
			fmt.printf("✓ %s\n", test.name)
			passed += 1
		} else {
			fmt.printf("✗ %s\n", test.name)
			failed += 1
		}
	}

	fmt.println("")
	fmt.println("========================================")
	fmt.println("Test Summary")
	fmt.println("========================================")
	fmt.printf("Passed: %d\n", passed)
	fmt.printf("Failed: %d\n", failed)
	fmt.println("")

	if failed == 0 {
		fmt.println("All tests passed! ✓")
	} else {
		fmt.println("Some tests failed ✗")
	}

	return passed, failed
}

main :: proc() {
	run_all_tests()
}