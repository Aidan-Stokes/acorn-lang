package ast

import "core:mem"

Node_Kind :: enum {
    Invalid,
    Program,
    Int_Literal,
    Float_Literal,
    String_Literal,
    Char_Literal,
    Bool_Literal,
    Ident,
    Binary_Expr,
    Unary_Expr,
    Call_Expr,
    Pipe_Expr,
    Array_Literal,
    Index_Expr,
    Struct_Literal,
    Member_Expr,

    Fn_Decl,
    Param,
    Struct_Decl,
    Enum_Decl,
    Field,
    Enum_Variant,

    Block_Stmt,
    Return_Stmt,
    If_Stmt,
    For_Stmt,
    For_In_Stmt,
    For_Condition_Stmt,
    Match_Stmt,
    Break_Stmt,
    Continue_Stmt,
    Assign_Stmt,
    Var_Decl,
    Const_Decl,
    Expr_Stmt,
    Import_Stmt,
}

Type :: struct {
    name:           string,
    is_array:       bool,
    array_size:     int,
    pointer_level:  int,
    base_type:      string,
}

Type_Kind :: enum {
    Invalid,
    Int,
    String,
    Bool,
    Void,
    Named,
    Array,
    Fn,
}

Type_Info :: struct {
    kind:         Type_Kind,
    name:         string,
    element_type: ^Type_Info,
    param_types:  []^Type_Info,
    return_type: ^Type_Info,
}

Node :: struct {
    kind: Node_Kind,
    type: ^Type_Info,

    int_value:    int,
    float_value:  f64,
    string_value: string,
    bool_value:   bool,

    name: string,

    left:    ^Node,
    right:   ^Node,
    operator: string,
    operand: ^Node,

    callee:    ^Node,
    arguments: []^Node,

    pipe_left:  ^Node,
    pipe_right: ^Node,

    elements:   []^Node,
    array_size: int,

    object: ^Node,
    field:  string,

    params:      []Param,
    return_type: Type,
    body:        ^Node,

    fields:        []Field,
    enum_variants: []Enum_Variant,

    cases: []^Node,

    statements:  []^Node,
    value:      ^Node,
    condition:   ^Node,
    else_branch: ^Node,
    init:        ^Node,
    update:      ^Node,

    target: string,

    for_var:        string,
    range_start:    ^Node,
    range_end:      ^Node,
    range_step:     ^Node,
    range_inclusive: bool,

    import_path:   string,
    match_value:    ^Node,
    match_patterns: []^Node,
}

Param :: struct {
    name: string,
    type: Type,
}

Field :: struct {
    name:  string,
    type:  Type,
    value: ^Node,
}

Enum_Variant :: struct {
    name:  string,
    value: int,
}

Program :: struct {
    declarations: []^Node,
}
