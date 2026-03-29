package parser

import "../ast"
import "../lexer"
import "core:strings"

parse_declaration :: proc(p: ^Parser) -> ^ast.Node {
    if match(p, .STRUCT) {
        name_tok := expect(p, .IDENT)
        name := strings.clone(name_tok.lexeme)
        return parse_struct_decl_with_name(p, name)
    }
    if match(p, .ENUM) {
        name_tok := expect(p, .IDENT)
        name := strings.clone(name_tok.lexeme)
        return parse_enum_decl_with_name(p, name)
    }
    if match(p, .IMPORT) {
        return parse_import(p)
    }

    return parse_statement(p)
}

parse_fn_body :: proc(p: ^Parser, name: string, generic_params: []string = nil) -> ^ast.Node {
    expect(p, .FN)
    expect(p, .LPAREN)

    params := [dynamic]ast.Param{}
    for !check(p, .RPAREN) {
        if len(params) > 0 {
            expect(p, .COMMA)
        }

        param_name_tok := expect(p, .IDENT)
        expect(p, .COLON)
        param_type := parse_type(p)
        param_name := strings.clone(param_name_tok.lexeme)
        append(&params, ast.Param{name = param_name, type = param_type})
    }
    expect(p, .RPAREN)

    return_type := ast.Type {
        name = "int",
    }
    if match(p, .ARROW) {
        return_type = parse_type(p)
    }

    body := parse_block(p)

    params_slice := make([]ast.Param, len(params))
    for i := 0; i < len(params); i += 1 {
        params_slice[i] = params[i]
    }
    delete(params)

    fn_node := ast.new_fn_decl(name, params_slice, return_type, body)
    fn_node.generic_params = generic_params
    return fn_node
}

parse_struct_decl_with_name :: proc(p: ^Parser, name: string) -> ^ast.Node {
    generic_params: [dynamic]string
    
    if check(p, .LESS) {
        expect(p, .LESS)
        if !check(p, .GREATER) {
            first_param := expect(p, .IDENT)
            append(&generic_params, strings.clone(first_param.lexeme))
            for match(p, .COMMA) {
                param := expect(p, .IDENT)
                append(&generic_params, strings.clone(param.lexeme))
            }
        }
        expect(p, .GREATER)
    }

    expect(p, .LBRACE)

    fields := [dynamic]ast.Field{}
    for !check(p, .RBRACE) {
        if len(fields) > 0 {
            if !match(p, .COMMA) {
                break
            }
        }

        field_name_tok := expect(p, .IDENT)
        expect(p, .COLON)
        field_type := parse_type(p)
        field_name := strings.clone(field_name_tok.lexeme)
        append(&fields, ast.Field{name = field_name, type = field_type})
    }
    expect(p, .RBRACE)

    node := ast.new_struct_decl(name, fields[:], generic_params[:])
    return node
}

parse_enum_decl_with_name :: proc(p: ^Parser, name: string) -> ^ast.Node {
    expect(p, .LBRACE)

    variants := [dynamic]ast.Enum_Variant{}
    current_value := 0

    for !check(p, .RBRACE) {
        if len(variants) > 0 {
            if check(p, .COMMA) {
                if peek_next(p) == .RBRACE {
                    advance(p)
                    break
                }
                advance(p)
            } else {
                break
            }
        }

        variant_name_tok := expect(p, .IDENT)
        variant_name := strings.clone(variant_name_tok.lexeme)

        value := current_value
        current_value += 1

        append(&variants, ast.Enum_Variant{name = variant_name, value = value})
    }
    expect(p, .RBRACE)

    node := ast.new_enum_decl(name, variants[:])
    return node
}

parse_type :: proc(p: ^Parser) -> ast.Type {
    pointer_level := 0
    for match(p, .CARET) {
        pointer_level += 1
    }

    if match(p, .LBRACKET) {
        expect(p, .RBRACKET)
        elem_type := parse_type(p)
        return ast.Type {
            name = elem_type.name,
            is_array = true,
            array_size = 0,
            pointer_level = pointer_level,
            base_type = elem_type.name,
        }
    }
    tok := expect(p, .IDENT)
    base := tok.lexeme

    if check(p, .LESS) {
        expect(p, .LESS)
        args := [dynamic]ast.Type{}
        if !check(p, .GREATER) {
            first_arg := parse_type(p)
            append(&args, first_arg)
            for match(p, .COMMA) {
                arg := parse_type(p)
                append(&args, arg)
            }
        }
        expect(p, .GREATER)
        return ast.Type {
            name = base,
            pointer_level = pointer_level,
            base_type = base,
            is_generic = true,
            generic_args = args[:],
        }
    }

    return ast.Type{name = base, pointer_level = pointer_level, base_type = base}
}

parse_block :: proc(p: ^Parser) -> ^ast.Node {
    expect(p, .LBRACE)

    statements := [dynamic]^ast.Node{}
    for !check(p, .RBRACE) && !check(p, .EOF) {
        for match(p, .SEMICOLON) {}
        if check(p, .RBRACE) || check(p, .EOF) do break
        stmt := parse_statement(p)
        if stmt != nil {
            append(&statements, stmt)
        }
    }
    expect(p, .RBRACE)

    node := ast.new_block(statements[:])
    return node
}

parse_import :: proc(p: ^Parser) -> ^ast.Node {
    path_tok := expect(p, .STRING)
    return ast.new_import(path_tok.lexeme)
}
