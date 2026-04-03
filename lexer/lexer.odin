package lexer

import "core:fmt"
import "core:strings"

Lexer :: struct {
    source:  string,
    start:   int,
    current: int,
    line:    int,
    column:  int,
}

init :: proc(source: string) -> Lexer {
    init_keywords()
    return Lexer{source = source, start = 0, current = 0, line = 1, column = 1}
}

is_at_end :: proc(l: ^Lexer) -> bool {
    return l.current >= len(l.source)
}

advance :: proc(l: ^Lexer) -> u8 {
    if is_at_end(l) do return 0
    ch := l.source[l.current]
    l.current += 1
    l.column += 1
    if ch == '\n' {
        l.line += 1
        l.column = 1
    }
    return ch
}

peek :: proc(l: ^Lexer) -> u8 {
    if is_at_end(l) do return 0
    return l.source[l.current]
}

peek_next :: proc(l: ^Lexer) -> u8 {
    if l.current + 1 >= len(l.source) do return 0
    return l.source[l.current + 1]
}

match :: proc(l: ^Lexer, expected: u8) -> bool {
    if is_at_end(l) do return false
    if l.source[l.current] != expected do return false
    l.current += 1
    l.column += 1
    return true
}

make_token :: proc(l: ^Lexer, kind: Token_Kind) -> Token {
    return Token {
        kind = kind,
        lexeme = l.source[l.start:l.current],
        char_value = 0,
        line = l.line,
        column = l.column - (l.current - l.start),
    }
}

error_token :: proc(l: ^Lexer, message: string) -> Token {
    return Token{kind = .Invalid, lexeme = message, char_value = 0, line = l.line, column = l.column}
}

skip_whitespace :: proc(l: ^Lexer) {
    for !is_at_end(l) {
        ch := peek(l)

        switch ch {
        case ' ', '\t', '\r', ';':
            advance(l)
        case '\n':
            advance(l)
        case '/':
            if peek_next(l) == '/' {
                for peek(l) != '\n' && !is_at_end(l) {
                    advance(l)
                }
            } else if peek_next(l) == '*' {
                advance(l)
                advance(l)
                for !is_at_end(l) {
                    if peek(l) == '*' && peek_next(l) == '/' {
                        advance(l)
                        advance(l)
                        break
                    }
                    advance(l)
                }
            } else {
                return
            }
        case:
            return
        }
    }
}

is_digit :: proc(ch: u8) -> bool {
    return ch >= '0' && ch <= '9'
}

is_hex_digit :: proc(ch: u8) -> bool {
    return (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F')
}

hex_to_int :: proc(ch: u8) -> int {
    if ch >= '0' && ch <= '9' do return int(ch - '0')
    if ch >= 'a' && ch <= 'f' do return int(ch - 'a' + 10)
    if ch >= 'A' && ch <= 'F' do return int(ch - 'A' + 10)
    return 0
}

scan_string :: proc(l: ^Lexer) -> Token {
    start_line := l.line
    start_column := l.column

    result := [dynamic]u8{}

    for peek(l) != '"' && !is_at_end(l) {
        ch := peek(l)

        if ch == '\\' && peek_next(l) != 0 {
            advance(l)
            next_ch := peek(l)

            switch next_ch {
            case 'n':
                append(&result, '\n')
            case 't':
                append(&result, '\t')
            case 'r':
                append(&result, '\r')
            case '\\':
                append(&result, '\\')
            case '"':
                append(&result, '"')
            case '\'':
                append(&result, '\'')
            case '0':
                append(&result, 0)
            case 'x':
                advance(l)
                hex1 := peek(l)
                if is_hex_digit(hex1) {
                    advance(l)
                    hex2 := peek(l)
                    if is_hex_digit(hex2) {
                        advance(l)
                        val := hex_to_int(hex1) * 16 + hex_to_int(hex2)
                        append(&result, u8(val))
                    } else {
                        val := hex_to_int(hex1)
                        append(&result, u8(val))
                    }
                }
            case:
                append(&result, '\\')
                append(&result, next_ch)
            }
        } else {
            append(&result, ch)
        }

        advance(l)
    }

    if is_at_end(l) {
        delete(result)
        l.line = start_line
        l.column = start_column
        return error_token(l, "Unterminated string")
    }

    advance(l)

    str := strings.clone_from_bytes(result[:])
    delete(result)

    return Token{
        kind = .STRING,
        lexeme = str,
        char_value = 0,
        line = start_line,
        column = start_column,
        string_data = nil,
    }
}

scan_raw_string :: proc(l: ^Lexer) -> Token {
    start_line := l.line
    start_column := l.column

    result := [dynamic]u8{}

    for peek(l) != '`' && !is_at_end(l) {
        ch := peek(l)
        append(&result, ch)
        advance(l)
    }

    if is_at_end(l) {
        delete(result)
        l.line = start_line
        l.column = start_column
        return error_token(l, "Unterminated raw string")
    }

    advance(l)

    str := strings.clone_from_bytes(result[:])
    delete(result)

    return Token{
        kind = .RAW_STRING,
        lexeme = str,
        char_value = 0,
        line = start_line,
        column = start_column,
        string_data = nil,
    }
}

scan_char :: proc(l: ^Lexer) -> Token {
    start_line := l.line
    start_column := l.column

    if is_at_end(l) || peek(l) == '"' {
        l.line = start_line
        l.column = start_column
        return error_token(l, "Unterminated character literal")
    }

    ch := peek(l)
    value: u8

    if ch == '\\' {
        advance(l)
        next_ch := peek(l)

        switch next_ch {
        case 'n':
            value = '\n'
            advance(l)
        case 't':
            value = '\t'
            advance(l)
        case 'r':
            value = '\r'
            advance(l)
        case '\\':
            value = '\\'
            advance(l)
        case '"':
            value = '"'
            advance(l)
        case '\'':
            value = '\''
            advance(l)
        case '0':
            value = 0
            advance(l)
        case 'x':
            advance(l)
            hex1 := peek(l)
            if is_hex_digit(hex1) {
                advance(l)
                hex2 := peek(l)
                if is_hex_digit(hex2) {
                    advance(l)
                    val := hex_to_int(hex1) * 16 + hex_to_int(hex2)
                    value = u8(val)
                } else {
                    val := hex_to_int(hex1)
                    value = u8(val)
                }
            }
        case:
            value = next_ch
            advance(l)
        }
    } else {
        value = ch
        advance(l)
    }

    if peek(l) != '\'' {
        l.line = start_line
        l.column = start_column
        return error_token(l, "Expected closing quote for character literal")
    }

    advance(l)

    return Token{
        kind = .CHAR,
        lexeme = "",
        char_value = value,
        line = start_line,
        column = start_column,
        string_data = nil,
    }
}

is_alpha :: proc(ch: u8) -> bool {
    return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

is_alphanumeric :: proc(ch: u8) -> bool {
    return is_alpha(ch) || is_digit(ch)
}

scan_number :: proc(l: ^Lexer) -> Token {
    has_dot := false

    for is_digit(peek(l)) {
        advance(l)
    }

    if peek(l) == '.' && is_digit(peek_next(l)) {
        has_dot = true
        advance(l)
        for is_digit(peek(l)) {
            advance(l)
        }
    }

    if peek(l) == 'e' || peek(l) == 'E' {
        advance(l)
        if peek(l) == '+' || peek(l) == '-' {
            advance(l)
        }
        if is_digit(peek(l)) {
            for is_digit(peek(l)) {
                advance(l)
            }
            return make_token(l, .FLOAT)
        }
        return error_token(l, "Invalid floating point literal")
    }

    if has_dot || is_digit(peek(l)) {
        return make_token(l, .FLOAT)
    }

    return make_token(l, .INT)
}

scan_identifier :: proc(l: ^Lexer) -> Token {
    for is_alphanumeric(peek(l)) {
        advance(l)
    }

    text := l.source[l.start:l.current]
    if kind, ok := keywords[text]; ok {
        return make_token(l, kind)
    }
    return make_token(l, .IDENT)
}

next_token :: proc(l: ^Lexer) -> Token {
    skip_whitespace(l)
    l.start = l.current

    if is_at_end(l) {
        return make_token(l, .EOF)
    }

    ch := advance(l)

    if is_alpha(ch) {
        return scan_identifier(l)
    }
    if is_digit(ch) {
        return scan_number(l)
    }

    switch ch {
    case '"':
        return scan_string(l)
    case '`':
        return scan_raw_string(l)
    case '\'':
        return scan_char(l)
    case '(':
        return make_token(l, .LPAREN)
    case ')':
        return make_token(l, .RPAREN)
    case '{':
        return make_token(l, .LBRACE)
    case '}':
        return make_token(l, .RBRACE)
    case '[':
        return make_token(l, .LBRACKET)
    case ']':
        return make_token(l, .RBRACKET)
    case ',':
        return make_token(l, .COMMA)
    case '.':
        if match(l, '.') {
            if match(l, '<') {
                return make_token(l, .RANGE_EXCLUSIVE)
            }
            return make_token(l, .RANGE_INCLUSIVE)
        }
        return make_token(l, .DOT)
    case ':':
        if match(l, ':') {
            return make_token(l, .DOUBLE_COLON)
        }
        return make_token(l, .COLON)
    case '<':
        if match(l, '-') {
            return make_token(l, .ARROW)
        }
        if match(l, '=') {
            return make_token(l, .LESS_EQUAL)
        }
        return make_token(l, .LESS)
    case '>':
        if match(l, '=') {
            return make_token(l, .GREATER_EQUAL)
        }
        return make_token(l, .GREATER)
    case '|':
        if match(l, '>') {
            return make_token(l, .PIPE)
        }
        return make_token(l, .BAR)
    case '+':
        return make_token(l, .PLUS)
    case '-':
        if match(l, '>') {
            return make_token(l, .ARROW)
        }
        return make_token(l, .MINUS)
    case '*':
        return make_token(l, .STAR)
    case '/':
        return make_token(l, .SLASH)
    case '%':
        return make_token(l, .PERCENT)
    case '=':
        if match(l, '>') {
            return make_token(l, .CASE_ARROW)
        }
        return make_token(l, .EQUAL)
    case '!':
        return make_token(l, .BANG)
    case '&':
        if match(l, '&') {
            return make_token(l, .ANDAND)
        }
        return make_token(l, .AMPERSAND)
    case '^':
        return make_token(l, .CARET)
    }

    return error_token(l, fmt.tprintf("Unexpected character: %c", ch))
}

scan :: proc(l: ^Lexer) -> [dynamic]Token {
    tokens := [dynamic]Token{}

    for {
        token := next_token(l)
        append(&tokens, token)
        if token.kind == .EOF || token.kind == .Invalid {
            break
        }
    }
    return tokens
}

destroy_tokens :: proc(tokens: ^[dynamic]Token) {
    for tok in tokens {
        if tok.string_data != nil {
            delete(tok.string_data)
        }
    }
    delete(tokens^)
}
