package parser

import "../ast"
import "../lexer"
import "../common"
import "core:mem"
import "core:fmt"

Parser :: struct {
    tokens:    []lexer.Token,
    current:   int,
    allocator: mem.Allocator,
    arena:     mem.Arena,
}

Error :: struct {
    message: string,
    line:    int,
    column:  int,
}

errors: [dynamic]Error

init :: proc(tokens: []lexer.Token, allocator: mem.Allocator = {}) -> Parser {
    alloc := allocator
    if alloc.data == nil {
        alloc = context.allocator
    }
    clear(&errors)
    return Parser{tokens = tokens, current = 0, allocator = alloc}
}

parser_allocator_init :: proc(p: ^Parser, capacity: int = 65536) {
    data := make([]u8, capacity)
    mem.arena_init(&p.arena, data)
    p.allocator = mem.arena_allocator(&p.arena)
}

alloc_node_ptr :: proc(p: ^Parser) -> ^ast.Node {
    size := size_of(ast.Node)
    align := align_of(ast.Node)
    bytes, err := mem.arena_alloc_bytes(&p.arena, size, align)
    if err != nil || len(bytes) == 0 {
        return nil
    }
    return cast(^ast.Node)(&bytes[0])
}

is_at_end :: proc(p: ^Parser) -> bool {
    return p.current >= len(p.tokens) - 1
}

peek :: proc(p: ^Parser) -> lexer.Token {
    if is_at_end(p) {
        return p.tokens[len(p.tokens) - 1]
    }
    return p.tokens[p.current]
}

peek_next :: proc(p: ^Parser) -> lexer.Token_Kind {
    next_idx := p.current + 1
    if next_idx < len(p.tokens) {
        return p.tokens[next_idx].kind
    }
    return .EOF
}

previous :: proc(p: ^Parser) -> lexer.Token {
    return p.tokens[p.current - 1]
}

advance :: proc(p: ^Parser) -> lexer.Token {
    if !is_at_end(p) {
        p.current += 1
    }
    return previous(p)
}

check :: proc(p: ^Parser, kind: lexer.Token_Kind) -> bool {
    if is_at_end(p) {
        return kind == .EOF
    }
    return peek(p).kind == kind
}

match :: proc(p: ^Parser, kinds: ..lexer.Token_Kind) -> bool {
    for kind in kinds {
        if check(p, kind) {
            advance(p)
            return true
        }
    }
    return false
}

match_seq2 :: proc(p: ^Parser, first, second: lexer.Token_Kind) -> bool {
    if is_at_end(p) do return false
    if !check(p, first) do return false
    next_i := p.current + 1
    if next_i >= len(p.tokens) do return false
    if p.tokens[next_i].kind != second do return false
    advance(p)
    advance(p)
    return true
}

expect :: proc(p: ^Parser, kind: lexer.Token_Kind) -> lexer.Token {
    if check(p, kind) {
        return advance(p)
    }
    tok := peek(p)
    add_error(fmt.tprintf("Expected %v but got %v", kind, tok.kind), tok.line, tok.column)
    advance(p)
    return lexer.Token{kind = .Invalid}
}

add_error :: proc(message: string, line: int, column: int) {
    append(&errors, Error{message, line, column})
}

print_errors :: proc() {
    if len(errors) == 0 do return
    for err in errors {
        common.print_error(err.message, err.line, err.column)
    }
}

has_errors :: proc() -> bool {
    return len(errors) > 0
}

parse_program :: proc(p: ^Parser) -> ^ast.Program {
    declarations := [dynamic]^ast.Node{}

    for {
        if is_at_end(p) {
            break
        }
        decl := parse_declaration(p)
        if decl == nil {
            break
        }
        append(&declarations, decl)
    }

    prog := new(ast.Program)
    prog.declarations = declarations[:]

    return prog
}

parse :: proc(source: string, allocator: mem.Allocator = {}) -> ^ast.Program {
    alloc := allocator
    if alloc.data == nil {
        alloc = context.allocator
    }
    l := lexer.init(source)
    tokens := lexer.scan(&l)
    p := init(tokens[:], alloc)
    parser_allocator_init(&p, len(source) * 2 + 65536)
    context.allocator = p.allocator
    prog := parse_program(&p)

    lexer.destroy_tokens(&tokens)

    return prog
}

destroy_program :: proc(prog: ^ast.Program) {
}
