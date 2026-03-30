package parser

import "../ast"
import "../lexer"
import "core:strconv"
import "core:fmt"

parse_expression :: proc(p: ^Parser) -> ^ast.Node {
    return parse_pipe(p)
}

parse_pipe :: proc(p: ^Parser) -> ^ast.Node {
    left := parse_or(p)

    for match(p, .PIPE) {
        right := parse_or(p)
        left = ast.new_pipe(left, right)
    }

    return left
}

parse_or :: proc(p: ^Parser) -> ^ast.Node {
    left := parse_and(p)

    for {
        if match_seq2(p, .BAR, .BAR) {
            right := parse_and(p)
            left = ast.new_binary(left, "||", right)
        } else {
            break
        }
    }

    return left
}

parse_and :: proc(p: ^Parser) -> ^ast.Node {
    left := parse_equality(p)

    for {
        if match_seq2(p, .AMPERSAND, .AMPERSAND) {
            right := parse_equality(p)
            left = ast.new_binary(left, "&&", right)
        } else {
            break
        }
    }

    return left
}

parse_equality :: proc(p: ^Parser) -> ^ast.Node {
    left := parse_comparison(p)

    for {
        if match_seq2(p, .EQUAL, .EQUAL) {
            right := parse_comparison(p)
            left = ast.new_binary(left, "==", right)
        } else if match_seq2(p, .BANG, .EQUAL) {
            right := parse_comparison(p)
            left = ast.new_binary(left, "!=", right)
        } else {
            break
        }
    }

    return left
}

parse_comparison :: proc(p: ^Parser) -> ^ast.Node {
    left := parse_term(p)

    for {
        if match(p, .GREATER_EQUAL) {
            right := parse_term(p)
            left = ast.new_binary(left, ">=", right)
        } else if match(p, .GREATER) {
            right := parse_term(p)
            left = ast.new_binary(left, ">", right)
        } else if match(p, .LESS_EQUAL) {
            right := parse_term(p)
            left = ast.new_binary(left, "<=", right)
        } else if match(p, .LESS) {
            right := parse_term(p)
            left = ast.new_binary(left, "<", right)
        } else {
            break
        }
    }

    return left
}

parse_term :: proc(p: ^Parser) -> ^ast.Node {
    left := parse_factor(p)

    for {
        if match(p, .PLUS) {
            right := parse_factor(p)
            left = ast.new_binary(left, "+", right)
        } else if match(p, .MINUS) {
            right := parse_factor(p)
            left = ast.new_binary(left, "-", right)
        } else {
            break
        }
    }

    return left
}

parse_factor :: proc(p: ^Parser) -> ^ast.Node {
    left := parse_unary(p)

    for {
        if match(p, .STAR) {
            right := parse_unary(p)
            left = ast.new_binary(left, "*", right)
        } else if match(p, .SLASH) {
            right := parse_unary(p)
            left = ast.new_binary(left, "/", right)
        } else if match(p, .PERCENT) {
            right := parse_unary(p)
            left = ast.new_binary(left, "%", right)
        } else {
            break
        }
    }

    return left
}

parse_unary :: proc(p: ^Parser) -> ^ast.Node {
    if match(p, .BANG) {
        operand := parse_unary(p)
        return ast.new_unary("!", operand)
    }
    if match(p, .MINUS) {
        operand := parse_unary(p)
        return ast.new_unary("-", operand)
    }
    if match(p, .AMPERSAND) {
        operand := parse_unary(p)
        return ast.new_unary("&", operand)
    }

    expr := parse_call(p)

    for {
        if match(p, .LBRACKET) {
            index := parse_expression(p)
            expect(p, .RBRACKET)
            expr = ast.new_index(expr, index)
        } else {
            break
        }
    }

    return expr
}

parse_call :: proc(p: ^Parser) -> ^ast.Node {
    expr := parse_primary(p)

    for {
        if match(p, .LPAREN) {
            args := [dynamic]^ast.Node{}
            for !check(p, .RPAREN) {
                if len(args) > 0 {
                    expect(p, .COMMA)
                }
                append(&args, parse_expression(p))
            }
            expect(p, .RPAREN)
            expr = ast.new_call(expr, args[:])
        } else if match(p, .DOT) {
            field_tok := expect(p, .IDENT)
            expr = ast.new_member(expr, field_tok.lexeme)
        } else if match(p, .CARET) {
            expr = ast.new_unary("^", expr)
        } else {
            break
        }
    }

    return expr
}

parse_primary :: proc(p: ^Parser) -> ^ast.Node {
    tok := peek(p)

    if match(p, .INT) {
        val, ok := strconv.parse_int(tok.lexeme)
        if !ok {
            add_error(fmt.tprintf("Invalid integer literal: %s", tok.lexeme), tok.line, tok.column)
            return ast.new_node(.Invalid)
        }
        return ast.new_int_literal(val)
    }

    if match(p, .FLOAT) {
        val, ok := strconv.parse_f64(tok.lexeme)
        if !ok {
            add_error(fmt.tprintf("Invalid float literal: %s", tok.lexeme), tok.line, tok.column)
            return ast.new_node(.Invalid)
        }
        return ast.new_float_literal(val)
    }

    if match(p, .STRING) || match(p, .RAW_STRING) {
        return ast.new_string_literal(tok.lexeme)
    }

    if match(p, .CHAR) {
        return ast.new_char_literal(tok.char_value)
    }

    if match(p, .TRUE) {
        return ast.new_bool_literal(true)
    }

    if match(p, .FALSE) {
        return ast.new_bool_literal(false)
    }

    if match(p, .IDENT) {
        ident_name := tok.lexeme
        
        if check(p, .LESS) {
            next_idx := p.current + 1
            if next_idx < len(p.tokens) && p.tokens[next_idx].kind == .IDENT {
                saved_pos := p.current
                expect(p, .LESS)
                type_args := [dynamic]ast.Type{}
                if !check(p, .GREATER) {
                    first_arg := parse_type(p)
                    append(&type_args, first_arg)
                    for match(p, .COMMA) {
                        arg := parse_type(p)
                        append(&type_args, arg)
                    }
                }
                if check(p, .GREATER) {
                    advance(p)
                    node := ast.new_ident(ident_name)
                    node.generic_args = type_args[:]
                    return node
                }
                p.current = saved_pos
            }
        }
        
        return ast.new_ident(ident_name)
    }

    if match(p, .LPAREN) {
        expr := parse_expression(p)
        expect(p, .RPAREN)
        return expr
    }

    if match(p, .LBRACKET) {
        elements := [dynamic]^ast.Node{}
        for !check(p, .RBRACKET) {
            if len(elements) > 0 {
                expect(p, .COMMA)
            }
            append(&elements, parse_expression(p))
        }
        expect(p, .RBRACKET)
        node := ast.new_array(elements[:])
        return node
    }

    add_error(fmt.tprintf("Unexpected token: %v", tok.kind), tok.line, tok.column)
    advance(p)
    return ast.new_node(.Invalid)
}
