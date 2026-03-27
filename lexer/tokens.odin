package lexer

Token_Kind :: enum {
    Invalid,
    EOF,
    IDENT,
    INT,
    FLOAT,
    STRING,
    RAW_STRING,
    CHAR,
    FN,
    STRUCT,
    ENUM,
    RETURN,
    IF,
    ELSE,
    FOR,
    MATCH,
    IMPORT,
    TRUE,
    FALSE,
    BREAK,
    CONTINUE,
    IN,
    ARROW,
    PIPE,
    BAR,
    COLON,
    DOUBLE_COLON,
    COMMA,
    DOT,
    LPAREN,
    RPAREN,
    LBRACE,
    RBRACE,
    LBRACKET,
    RBRACKET,
    PLUS,
    MINUS,
    STAR,
    SLASH,
    PERCENT,
    EQUAL,
    CONST,  // for typed constants: x: int = 10
    BANG,
    AMPERSAND,
    LESS,
    LESS_EQUAL,
    GREATER,
    GREATER_EQUAL,
    RANGE_INCLUSIVE,
    RANGE_EXCLUSIVE,
    CASE_ARROW,   // =>
    NEWLINE,
    SEMICOLON,
    CARET,
}

Token :: struct {
    kind:        Token_Kind,
    lexeme:      string,
    char_value:  u8,
    line:        int,
    column:      int,
    string_data: []u8,
}

Token_Entry :: struct {
    kind:        Token_Kind,
    lexeme:      string,
    char_value:  u8,
    line:        int,
    column:      int,
    string_data: []u8,
}

token_at :: proc(stream: ^#soa[dynamic]Token_Entry, index: int) -> Token {
    entry := stream[index]
    return Token {
        kind        = entry.kind,
        lexeme      = entry.lexeme,
        char_value  = entry.char_value,
        line        = entry.line,
        column      = entry.column,
        string_data = entry.string_data,
    }
}

keywords: map[string]Token_Kind
keywords_initialized := false

init_keywords :: proc() {
    if keywords_initialized do return
    keywords = make(map[string]Token_Kind)
    keywords["fn"] = .FN
    keywords["struct"] = .STRUCT
    keywords["enum"] = .ENUM
    keywords["return"] = .RETURN
    keywords["if"] = .IF
    keywords["else"] = .ELSE
    keywords["for"] = .FOR
    keywords["match"] = .MATCH
    keywords["import"] = .IMPORT
    keywords["true"] = .TRUE
    keywords["false"] = .FALSE
    keywords["break"] = .BREAK
    keywords["continue"] = .CONTINUE
    keywords["in"] = .IN
    keywords_initialized = true
}

destroy_keywords :: proc() {
    delete(keywords)
}
