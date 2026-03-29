package parser

import "../ast"
import "../lexer"
import "core:strings"

skip_semicolons :: proc(p: ^Parser) {
    for match(p, .SEMICOLON) {}
}

parse_statement :: proc(p: ^Parser) -> ^ast.Node {
    skip_semicolons(p)
    if match(p, .RETURN) {
        value: ^ast.Node = nil
        if !check(p, .LBRACE) && !check(p, .NEWLINE) {
            value = parse_expression(p)
        }
        skip_semicolons(p)
        return ast.new_return(value)
    }

    if match(p, .IF) {
        return parse_if_stmt(p)
    }

    if match(p, .FOR) {
        return parse_for_stmt(p)
    }

    if match(p, .MATCH) {
        return parse_match_stmt(p)
    }

    if match(p, .BREAK) {
        return ast.new_break()
    }

    if match(p, .CONTINUE) {
        return ast.new_continue()
    }

    if check(p, .IDENT) {
        next_idx := p.current + 1
        if next_idx < len(p.tokens) {
            next_tok := p.tokens[next_idx]
            if next_tok.kind == .ARROW {
                return parse_assignment(p)
            }
            if next_tok.kind == .EQUAL {
                return parse_const_decl(p)
            }
            if next_tok.kind == .COLON {
                return parse_var_or_const_decl(p)
            }
            if next_tok.kind == .DOUBLE_COLON {
                name := strings.clone(peek(p).lexeme)
                advance(p)
                advance(p)
                if match(p, .STRUCT) {
                    return parse_struct_decl_with_name(p, name)
                }
                if match(p, .ENUM) {
                    return parse_enum_decl_with_name(p, name)
                }
                return parse_fn_body(p, name)
            }
            if next_tok.kind == .LESS {
                first_token := p.tokens[p.current]
                name := strings.clone(first_token.lexeme)
                
                advance(p)
                expect(p, .LESS)
                
                generic_params: [dynamic]string
                if !check(p, .GREATER) {
                    first_param := expect(p, .IDENT)
                    append(&generic_params, strings.clone(first_param.lexeme))
                    for match(p, .COMMA) {
                        param := expect(p, .IDENT)
                        append(&generic_params, strings.clone(param.lexeme))
                    }
                }
                expect(p, .GREATER)
                
                if check(p, .DOUBLE_COLON) {
                    advance(p)
                    if match(p, .STRUCT) {
                        return parse_struct_decl_with_name(p, name)
                    }
                    if match(p, .ENUM) {
                        return parse_enum_decl_with_name(p, name)
                    }
                    return parse_fn_body(p, name, generic_params[:])
                }
            }
        }
    }

    expr := parse_expression(p)
    skip_semicolons(p)
    return ast.new_expr_stmt(expr)
}

parse_if_stmt :: proc(p: ^Parser) -> ^ast.Node {
    expect(p, .LPAREN)
    condition := parse_expression(p)
    expect(p, .RPAREN)

    then_branch := parse_block(p)

    else_branch: ^ast.Node = nil
    if match(p, .ELSE) {
        if check(p, .IF) {
            else_branch = parse_if_stmt(p)
        } else {
            else_branch = parse_block(p)
        }
    }

    return ast.new_if(condition, then_branch, else_branch)
}

parse_for_stmt :: proc(p: ^Parser) -> ^ast.Node {
    if check(p, .LPAREN) {
        advance(p)

        init: ^ast.Node = nil
        if !check(p, .SEMICOLON) {
            if check(p, .IDENT) {
                next_idx := p.current + 1
                if next_idx < len(p.tokens) {
                    next_tok := p.tokens[next_idx]
                    if next_tok.kind == .ARROW {
                        init = parse_assignment(p)
                    } else if next_tok.kind == .COLON {
                        init = parse_var_decl(p)
                    } else {
                        init = parse_expression(p)
                    }
                } else {
                    init = parse_expression(p)
                }
            } else {
                init = parse_expression(p)
            }
        }
        expect(p, .SEMICOLON)

        condition: ^ast.Node = nil
        if !check(p, .SEMICOLON) {
            condition = parse_expression(p)
        }
        expect(p, .SEMICOLON)

        update: ^ast.Node = nil
        if !check(p, .RPAREN) {
            if check(p, .IDENT) {
                next_idx := p.current + 1
                if next_idx < len(p.tokens) {
                    next_tok := p.tokens[next_idx]
                    if next_tok.kind == .ARROW {
                        update = parse_assignment(p)
                    } else if next_tok.kind == .COLON {
                        update = parse_var_decl(p)
                    } else {
                        update = parse_expression(p)
                    }
                } else {
                    update = parse_expression(p)
                }
            } else {
                update = parse_expression(p)
            }
        }
        expect(p, .RPAREN)

        body := parse_block(p)
        return ast.new_for(init, condition, update, body)
    }

    if check(p, .IDENT) {
        if p.current + 2 < len(p.tokens) {
            next_tok := p.tokens[p.current + 1]
            if next_tok.kind == .IN {
                var_name := advance(p).lexeme
                advance(p)
                start := parse_expression(p)

                inclusive := true
                if check(p, .RANGE_INCLUSIVE) {
                    advance(p)
                } else if check(p, .RANGE_EXCLUSIVE) {
                    advance(p)
                    inclusive = false
                } else {
                    add_error(
                        "Expected '..' or '..<' in for-in range",
                        peek(p).line,
                        peek(p).column,
                    )
                }

                end := parse_expression(p)

                step: ^ast.Node = nil
                if check(p, .IDENT) && peek(p).lexeme == "by" {
                    advance(p)
                    step = parse_expression(p)
                }

                body := parse_block(p)
                return ast.new_for_in(var_name, start, end, inclusive, step, body)
            }
        }
    }

    if !check(p, .LBRACE) {
        condition := parse_expression(p)
        body := parse_block(p)
        return ast.new_for_condition(condition, body)
    }

    if check(p, .LBRACE) {
        body := parse_block(p)
        true_node := ast.new_bool_literal(true)
        return ast.new_for_condition(true_node, body)
    }

    add_error("Invalid for loop syntax", peek(p).line, peek(p).column)
    return ast.new_node(.Invalid)
}

parse_assignment :: proc(p: ^Parser) -> ^ast.Node {
    name_tok := advance(p)
    advance(p)

    value := parse_expression(p)
    if value != nil && value.kind == .Ident && check(p, .LBRACE) {
        ident_name := value.name
        fields := [dynamic]ast.Field{}
        advance(p)
        for !check(p, .RBRACE) {
            if len(fields) > 0 {
                expect(p, .COMMA)
            }
            field_name_tok := expect(p, .IDENT)
            expect(p, .COLON)
            field_value := parse_expression(p)
            append(&fields, ast.Field{name = field_name_tok.lexeme, value = field_value})
        }
        expect(p, .RBRACE)
        value = ast.new_struct_literal(ident_name, fields[:])
    }

    return ast.new_assign(strings.clone(name_tok.lexeme), value)
}

parse_var_decl :: proc(p: ^Parser) -> ^ast.Node {
    name_tok := advance(p)
    advance(p)

    var_type := parse_type(p)

    value: ^ast.Node = nil
    if match(p, .ARROW) {
        value = parse_expression(p)
        if value != nil && value.kind == .Ident && check(p, .LBRACE) {
            ident_name := value.name
            fields := [dynamic]ast.Field{}
            advance(p)
            for !check(p, .RBRACE) {
                if len(fields) > 0 {
                    expect(p, .COMMA)
                }
                field_name_tok := expect(p, .IDENT)
                expect(p, .COLON)
                field_value := parse_expression(p)
                append(&fields, ast.Field{name = field_name_tok.lexeme, value = field_value})
            }
            expect(p, .RBRACE)
            value = ast.new_struct_literal(ident_name, fields[:])
        }
    }

    return ast.new_var_decl(name_tok.lexeme, var_type, value)
}

parse_var_or_const_decl :: proc(p: ^Parser) -> ^ast.Node {
    name_tok := advance(p)
    advance(p)

    var_type := parse_type(p)

    if match(p, .EQUAL) {
        value := parse_expression(p)
        return ast.new_const_decl(strings.clone(name_tok.lexeme), var_type, value)
    }

    value: ^ast.Node = nil
    if match(p, .ARROW) {
        value = parse_expression(p)
        if value != nil && value.kind == .Ident && check(p, .LBRACE) {
            ident_name := value.name
            fields := [dynamic]ast.Field{}
            advance(p)
            for !check(p, .RBRACE) {
                if len(fields) > 0 {
                    expect(p, .COMMA)
                }
                field_name_tok := expect(p, .IDENT)
                expect(p, .COLON)
                field_value := parse_expression(p)
                append(&fields, ast.Field{name = field_name_tok.lexeme, value = field_value})
            }
            expect(p, .RBRACE)
            value = ast.new_struct_literal(ident_name, fields[:])
        }
    }

    return ast.new_var_decl(strings.clone(name_tok.lexeme), var_type, value)
}

parse_match_stmt :: proc(p: ^Parser) -> ^ast.Node {
    value := parse_call(p)

    patterns := [dynamic]^ast.Node{}
    bodies := [dynamic]^ast.Node{}
    expect(p, .LBRACE)

    for !check(p, .RBRACE) {
        pattern := parse_call(p)
        append(&patterns, pattern)
        expect(p, .CASE_ARROW)
        body := parse_statement(p)
        append(&bodies, body)
    }

    expect(p, .RBRACE)

    return ast.new_match(value, patterns[:], bodies[:])
}

parse_const_decl :: proc(p: ^Parser) -> ^ast.Node {
    name_tok := advance(p)
    name := strings.clone(name_tok.lexeme)

    var_type: ast.Type = {}
    if match(p, .COLON) {
        var_type = parse_type(p)
    }

    expect(p, .EQUAL)

    value := parse_expression(p)

    return ast.new_const_decl(name, var_type, value)
}
