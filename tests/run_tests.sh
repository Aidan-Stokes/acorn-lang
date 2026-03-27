#!/usr/bin/env bash

# Test runner for Acorn compiler

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

ACORN="./acorn"
FAILED=0
PASSED=0

run_test() {
    local name="$1"
    local expected="$2"
    local code="$3"
    
    # Write code to temp file
    echo "$code" > /tmp/test_temp.acorn
    
    # Run acorn check first
    if ! $ACORN check /tmp/test_temp.acorn > /tmp/test_stderr.acorn 2>&1; then
        # Expected behavior: type error detected
        if [ "$expected" = "error" ]; then
            PASSED=$((PASSED + 1))
            echo "✓ $name"
        else
            FAILED=$((FAILED + 1))
            echo "✗ $name (expected success, got error)"
            cat /tmp/test_stderr.acorn
        fi
        return
    fi
    
    # Compile
    if ! $ACORN build /tmp/test_temp.acorn > /tmp/test_stderr.acorn 2>&1; then
        FAILED=$((FAILED + 1))
        echo "✗ $name (build failed)"
        cat /tmp/test_stderr.acorn
        return
    fi
    
    # Run
    output=$(./acorn_out 2>/dev/null)

    # Normalize output (trim whitespace)
    output=$(echo "$output" | tr -d '\n\r')
    
    # Check result
    if [ "$expected" = "error" ]; then
        FAILED=$((FAILED + 1))
        echo "✗ $name (expected error, got success)"
    elif [ "$expected" = "$output" ]; then
        PASSED=$((PASSED + 1))
        echo "✓ $name"
    else
        FAILED=$((FAILED + 1))
        echo "✗ $name (expected '$expected', got '$output')"
    fi
}

echo "========================================"
echo "Acorn Compiler Test Suite"
echo "========================================"
echo ""

# Basic function tests
echo "=== Basic Function Tests ==="
run_test "hello_world" "42" 'main :: fn() -> int { print(42); return 0 }'
run_test "simple_print" "Hello" 'main :: fn() -> int { print("Hello"); return 0 }'

# Variable tests
echo ""
echo "=== Variable Tests ==="
run_test "simple_assign" "10" 'main :: fn() -> int { x <- 10; print(x); return 0 }'
run_test "typed_int" "42" 'main :: fn() -> int { x: int <- 42; print(x); return 0 }'
run_test "typed_bool_true" "1" 'main :: fn() -> int { x: bool <- true; print(x); return 0 }'
run_test "typed_bool_false" "0" 'main :: fn() -> int { x: bool <- false; print(x); return 0 }'

# Arithmetic tests
echo ""
echo "=== Arithmetic Tests ==="
run_test "add" "13" 'main :: fn() -> int { a <- 10; b <- 3; print(a + b); return 0 }'
run_test "subtract" "7" 'main :: fn() -> int { a <- 10; b <- 3; print(a - b); return 0 }'
run_test "multiply" "30" 'main :: fn() -> int { a <- 10; b <- 3; print(a * b); return 0 }'
run_test "divide" "3" 'main :: fn() -> int { a <- 10; b <- 3; print(a / b); return 0 }'
run_test "modulo" "1" 'main :: fn() -> int { a <- 10; b <- 3; print(a % b); return 0 }'

# Comparison tests
echo ""
echo "=== Comparison Tests ==="
run_test "equal_true" "1" 'main :: fn() -> int { print(5 == 5); return 0 }'
run_test "equal_false" "0" 'main :: fn() -> int { print(5 == 3); return 0 }'
run_test "not_equal_true" "1" 'main :: fn() -> int { print(5 != 3); return 0 }'
run_test "greater_than_true" "1" 'main :: fn() -> int { print(5 > 3); return 0 }'
run_test "less_than_true" "1" 'main :: fn() -> int { print(3 < 5); return 0 }'

# Logical tests
echo ""
echo "=== Logical Tests ==="
run_test "and_true" "1" 'main :: fn() -> int { print(true && true); return 0 }'
run_test "and_false" "0" 'main :: fn() -> int { print(true && false); return 0 }'
run_test "or_true" "1" 'main :: fn() -> int { print(true || false); return 0 }'
run_test "or_false" "0" 'main :: fn() -> int { print(false || false); return 0 }'
run_test "not_true" "0" 'main :: fn() -> int { print(!true); return 0 }'
run_test "not_false" "1" 'main :: fn() -> int { print(!false); return 0 }'

# If/else tests
echo ""
echo "=== If/Else Tests ==="
run_test "if_true" "yes" 'main :: fn() -> int { if (true) { print("yes") }; return 0 }'
run_test "if_false" "" 'main :: fn() -> int { if (false) { print("yes") }; return 0 }'
run_test "if_else_true" "yes" 'main :: fn() -> int { if (true) { print("yes") } else { print("no") }; return 0 }'
run_test "if_else_false" "no" 'main :: fn() -> int { if (false) { print("yes") } else { print("no") }; return 0 }'

# Loop tests
echo ""
echo "=== Loop Tests ==="
run_test "for_range" "0123" 'main :: fn() -> int { for i in 0..3 { print(i) }; return 0 }'
run_test "for_range_exclusive" "012" 'main :: fn() -> int { for i in 0..<3 { print(i) }; return 0 }'
run_test "for_range_by" "0246" 'main :: fn() -> int { for i in 0..6 by 2 { print(i) }; return 0 }'
run_test "for_while" "012" 'main :: fn() -> int { i <- 0; for i < 3 { print(i); i <- i + 1 }; return 0 }'
run_test "infinite_loop_break" "5" 'main :: fn() -> int { i <- 0; for { i <- i + 1; if (i > 4) { break } }; print(i); return 0 }'

# Array tests
echo ""
echo "=== Array Tests ==="
run_test "array_literal" "1" 'main :: fn() -> int { arr <- [1, 2, 3]; print(arr[0]); return 0 }'
run_test "array_index" "2" 'main :: fn() -> int { arr <- [1, 2, 3]; print(arr[1]); return 0 }'

# Float tests
echo ""
echo "=== Float Tests ==="
run_test "float_literal" "3" 'main :: fn() -> int { x <- 3.14; print(x); return 0 }'
run_test "float_add" "10" 'main :: fn() -> int { x <- 5.0; y <- 5.0; print(x + y); return 0 }'

# Type error tests
echo ""
echo "=== Type Error Tests ==="
run_test "type_error_string_to_int" "error" 'main :: fn() -> int { x: int <- "hello"; return 0 }'
run_test "type_error_bool_to_int" "error" 'main :: fn() -> int { x: int <- true; return 0 }'
run_test "type_error_int_to_bool" "error" 'main :: fn() -> int { x: bool <- 42; return 0 }'
run_test "type_error_arith_strings" "error" 'main :: fn() -> int { x <- "a" + "b"; return 0 }'

# Struct tests
echo ""
echo "=== Struct Tests ==="
run_test "struct_decl" "Point" 'Point :: struct { x: int, y: int }
main :: fn() -> int { print("Point"); return 0 }'
run_test "struct_literal" "10" 'Point :: struct { x: int, y: int }
main :: fn() -> int { p: Point <- Point{x: 10, y: 20}; print(p.x); return 0 }'

# Enum tests
echo ""
echo "=== Enum Tests ==="
run_test "enum_decl" "Enum" 'main :: fn() -> int { Color :: enum { Red, Green, Blue }; print("Enum"); return 0 }'
run_test "enum_variant" "1" 'Color :: enum { Red, Green, Blue }
main :: fn() -> int { x <- Color.Green; print(x); return 0 }'

# Match tests
echo ""
echo "=== Match Tests ==="
run_test "match_simple" "b" 'main :: fn() -> int { x <- 1; match x { 0 => print("a") 1 => print("b") }; return 0 }'
run_test "match_enum" "Green" 'Color :: enum { Red, Green, Blue }
main :: fn() -> int { x <- Color.Green; match x { Color.Red => print("Red") Color.Green => print("Green") }; return 0 }'

# Pointer tests
echo ""
echo "=== Pointer Tests ==="
run_test "pointer_address_of" "42" 'main :: fn() -> int { x <- 42; y <- &x; print(y^); return 0 }'
run_test "pointer_deref" "42" 'main :: fn() -> int { x <- 42; y <- &x; z <- y^; print(z); return 0 }'

# Constant tests
echo ""
echo "=== Constant Tests ==="
run_test "const_simple" "42" 'x = 42
main :: fn() -> int { print(x); return 0 }'
run_test "const_typed_int" "10" 'x: int = 10
main :: fn() -> int { print(x); return 0 }'
run_test "const_typed_float" "3.140000" 'x: f64 = 3.14
main :: fn() -> int { print(x); return 0 }'
run_test "const_multiple" "15" 'x = 10
y = 5
main :: fn() -> int { print(x + y); return 0 }'

# Global variable tests
echo ""
echo "=== Global Variable Tests ==="
run_test "global_var_int" "42" 'x <- 42
main :: fn() -> int { print(x); return 0 }'
run_test "global_var_multiple" "15" 'x <- 10
y <- 5
main :: fn() -> int { print(x + y); return 0 }'
run_test "global_var_reassign" "20" 'x <- 10
main :: fn() -> int { x <- 20; print(x); return 0 }'

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "All tests passed! ✓"
    exit 0
else
    echo "Some tests failed ✗"
    exit 1
fi
