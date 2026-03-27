#!/bin/bash
# Run all Acorn examples

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACORN_DIR="$(dirname "$SCRIPT_DIR")"
ACORN="$ACORN_DIR/acorn"

if [ ! -f "$ACORN" ]; then
    echo "Error: acorn binary not found at $ACORN"
    echo "Please build with: cd $ACORN_DIR && odin build . -file -out:acorn"
    exit 1
fi

echo "========================================"
echo "Running Acorn Language Examples"
echo "========================================"
echo ""

cd "$SCRIPT_DIR"

for f in *.acorn; do
    # Skip error example files
    if [[ "$f" == *_error.acorn ]]; then
        continue
    fi
    echo "----------------------------------------"
    echo "Running: $f"
    echo "----------------------------------------"
    "$ACORN" check "$f" 2>&1
    "$ACORN" build "$f" -o /tmp/acorn_example 2>/dev/null
    /tmp/acorn_example
    echo ""
done

echo "========================================"
echo "All examples completed"
echo "========================================"
