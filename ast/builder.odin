package ast

import "core:fmt"
import "core:mem"
import "core:strings"

Node_Allocator :: struct {
    using allocator: mem.Allocator,
    arena:           mem.Arena,
}

init_allocator :: proc(alloc: ^Node_Allocator, capacity: int = 65536) {
    data := make([]u8, capacity)
    mem.arena_init(&alloc.arena, data)
    alloc.allocator = mem.arena_allocator(&alloc.arena)
}

get_allocator :: proc() -> mem.Allocator {
    return context.allocator
}

alloc_node :: proc(allocator: mem.Allocator = {}) -> ^Node {
    alloc := allocator
    if alloc.data == nil {
        alloc = get_allocator()
    }
    n := new(Node, alloc)
    return n
}

new_node :: proc(kind: Node_Kind, allocator: mem.Allocator = {}) -> ^Node {
    n := alloc_node(allocator)
    n.kind = kind
    return n
}

new_int_literal :: proc(value: int, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Int_Literal, allocator)
    n.int_value = value
    return n
}

new_float_literal :: proc(value: f64, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Float_Literal, allocator)
    n.float_value = value
    return n
}

new_string_literal :: proc(value: string, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.String_Literal, allocator)
    n.string_value = value
    return n
}

new_char_literal :: proc(value: u8, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Char_Literal, allocator)
    n.int_value = int(value)
    return n
}

new_bool_literal :: proc(value: bool, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Bool_Literal, allocator)
    n.bool_value = value
    return n
}

new_ident :: proc(name: string, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Ident, allocator)
    n.name = name
    return n
}

new_binary :: proc(left: ^Node, op: string, right: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Binary_Expr, allocator)
    n.left = left
    n.operator = op
    n.right = right
    return n
}

new_unary :: proc(op: string, operand: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Unary_Expr, allocator)
    n.operator = op
    n.operand = operand
    return n
}

new_call :: proc(callee: ^Node, arguments: []^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Call_Expr, allocator)
    n.callee = callee
    n.arguments = arguments
    return n
}

new_pipe :: proc(left: ^Node, right: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Pipe_Expr, allocator)
    n.pipe_left = left
    n.pipe_right = right
    return n
}

new_array :: proc(elements: []^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Array_Literal, allocator)
    n.elements = elements
    n.array_size = len(elements)
    return n
}

new_index :: proc(object: ^Node, index: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Index_Expr, allocator)
    n.object = object
    n.value = index
    return n
}

new_struct_literal :: proc(name: string, fields: []Field, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Struct_Literal, allocator)
    n.name = name
    n.fields = fields
    return n
}

new_member :: proc(object: ^Node, field: string, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Member_Expr, allocator)
    n.object = object
    n.field = field
    return n
}

new_fn_decl :: proc(name: string, params: []Param, return_type: Type, body: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Fn_Decl, allocator)
    n.name = name
    n.params = params
    n.return_type = return_type
    n.body = body
    return n
}

new_struct_decl :: proc(name: string, fields: []Field, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Struct_Decl, allocator)
    n.name = name
    n.fields = fields
    return n
}

new_enum_decl :: proc(name: string, variants: []Enum_Variant, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Enum_Decl, allocator)
    n.name = name
    n.enum_variants = variants
    return n
}

new_block :: proc(statements: []^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Block_Stmt, allocator)
    n.statements = statements
    return n
}

new_return :: proc(value: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Return_Stmt, allocator)
    n.value = value
    return n
}

new_if :: proc(condition: ^Node, then_branch: ^Node, else_branch: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.If_Stmt, allocator)
    n.condition = condition
    n.body = then_branch
    n.else_branch = else_branch
    return n
}

new_for :: proc(init: ^Node, condition: ^Node, update: ^Node, body: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.For_Stmt, allocator)
    n.init = init
    n.condition = condition
    n.update = update
    n.body = body
    return n
}

new_assign :: proc(target: string, value: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Assign_Stmt, allocator)
    n.target = target
    n.value = value
    return n
}

new_var_decl :: proc(name: string, type: Type, value: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Var_Decl, allocator)
    n.name = name
    n.return_type = type
    n.value = value
    return n
}

new_const_decl :: proc(name: string, type: Type, value: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Const_Decl, allocator)
    n.name = name
    n.return_type = type
    n.value = value
    return n
}

new_expr_stmt :: proc(expr: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Expr_Stmt, allocator)
    n.value = expr
    return n
}

new_import :: proc(path: string, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Import_Stmt, allocator)
    n.import_path = path
    return n
}

new_for_in :: proc(var_name: string, start: ^Node, end: ^Node, inclusive: bool, step: ^Node, body: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.For_In_Stmt, allocator)
    n.for_var = var_name
    n.range_start = start
    n.range_end = end
    n.range_inclusive = inclusive
    n.range_step = step
    n.body = body
    return n
}

new_for_condition :: proc(condition: ^Node, body: ^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.For_Condition_Stmt, allocator)
    n.condition = condition
    n.body = body
    return n
}

new_match :: proc(value: ^Node, patterns: []^Node, cases: []^Node, allocator: mem.Allocator = {}) -> ^Node {
    n := new_node(.Match_Stmt, allocator)
    n.match_value = value
    n.match_patterns = patterns
    n.cases = cases
    return n
}

new_break :: proc(allocator: mem.Allocator = {}) -> ^Node {
    return new_node(.Break_Stmt, allocator)
}

new_continue :: proc(allocator: mem.Allocator = {}) -> ^Node {
    return new_node(.Continue_Stmt, allocator)
}

destroy_node :: proc(n: ^Node) {
    if n == nil do return

    #partial switch n.kind {
    case .Int_Literal, .Float_Literal, .Bool_Literal:
    case .String_Literal:
    case .Ident, .Field:
    case .Binary_Expr, .Unary_Expr:
        destroy_node(n.left)
        destroy_node(n.right)
        destroy_node(n.operand)
    case .Call_Expr:
        destroy_node(n.callee)
        for arg in n.arguments do destroy_node(arg)
    case .Pipe_Expr:
        destroy_node(n.pipe_left)
        destroy_node(n.pipe_right)
    case .Array_Literal:
        for elem in n.elements do destroy_node(elem)
    case .Index_Expr:
        destroy_node(n.object)
        destroy_node(n.value)
    case .Struct_Literal:
    case .Member_Expr:
        destroy_node(n.object)
    case .Fn_Decl:
        destroy_node(n.body)
    case .Block_Stmt:
        for stmt in n.statements do destroy_node(stmt)
    case .Return_Stmt, .Expr_Stmt:
        destroy_node(n.value)
    case .If_Stmt:
        destroy_node(n.condition)
        destroy_node(n.body)
        destroy_node(n.else_branch)
    case .For_Stmt:
        destroy_node(n.init)
        destroy_node(n.condition)
        destroy_node(n.update)
        destroy_node(n.body)
    case .For_In_Stmt:
        destroy_node(n.range_start)
        destroy_node(n.range_end)
        destroy_node(n.range_step)
        destroy_node(n.body)
    case .For_Condition_Stmt:
        destroy_node(n.condition)
        destroy_node(n.body)
    case .Match_Stmt:
        destroy_node(n.match_value)
        for p in n.match_patterns {
            destroy_node(p)
        }
        for c in n.cases {
            destroy_node(c)
        }
    case .Assign_Stmt:
        destroy_node(n.value)
    case .Var_Decl:
        destroy_node(n.value)
    case .Import_Stmt:
    }

    free(n)
}

destroy_program :: proc(p: ^Program) {
    if p == nil do return
    for decl in p.declarations {
        destroy_node(decl)
    }
    free(p)
}

print_node :: proc(n: ^Node, indent: int = 0) {
    prefix := strings.repeat("  ", indent)

    if n == nil {
        fmt.printf("%s<nil>\n", prefix)
        return
    }

    #partial switch n.kind {
    case .Invalid:
        fmt.printf("%sInvalid\n", prefix)
    case .Program:
        fmt.printf("%sProgram\n", prefix)
    case .Int_Literal:
        fmt.printf("%sInt_Literal: %d\n", prefix, n.int_value)
    case .Float_Literal:
        fmt.printf("%sFloat_Literal: %f\n", prefix, n.float_value)
    case .String_Literal:
        fmt.printf("%sString_Literal: %s\n", prefix, n.string_value)
    case .Bool_Literal:
        fmt.printf("%sBool_Literal: %v\n", prefix, n.bool_value)
    case .Ident:
        fmt.printf("%sIdent: %s\n", prefix, n.name)
    case .Binary_Expr:
        fmt.printf("%sBinary_Expr: %s\n", prefix, n.operator)
        print_node(n.left, indent + 1)
        print_node(n.right, indent + 1)
    case .Unary_Expr:
        fmt.printf("%sUnary_Expr: %s\n", prefix, n.operator)
        print_node(n.operand, indent + 1)
    case .Call_Expr:
        fmt.printf("%sCall_Expr\n", prefix)
        print_node(n.callee, indent + 1)
        fmt.printf("%s  Arguments:\n", prefix)
        for i := 0; i < len(n.arguments); i += 1 {
            arg := n.arguments[i]
            print_node(arg, indent + 2)
        }
    case .Pipe_Expr:
        fmt.printf("%sPipe_Expr\n", prefix)
        print_node(n.pipe_left, indent + 1)
        print_node(n.pipe_right, indent + 1)
    case .Array_Literal:
        fmt.printf("%sArray_Literal\n", prefix)
        for i := 0; i < len(n.elements); i += 1 {
            elem := n.elements[i]
            print_node(elem, indent + 1)
        }
    case .Index_Expr:
        fmt.printf("%sIndex_Expr\n", prefix)
        print_node(n.object, indent + 1)
        print_node(n.value, indent + 1)
    case .Struct_Literal:
        fmt.printf("%sStruct_Literal: %s\n", prefix, n.name)
    case .Member_Expr:
        fmt.printf("%sMember_Expr: %s\n", prefix, n.field)
        print_node(n.object, indent + 1)
    case .Fn_Decl:
        fmt.printf("%sFn_Decl: %s\n", prefix, n.name)
        print_node(n.body, indent + 1)
    case .Struct_Decl:
        fmt.printf("%sStruct_Decl: %s\n", prefix, n.name)
    case .Enum_Decl:
        fmt.printf("%sEnum_Decl: %s\n", prefix, n.name)
    case .Block_Stmt:
        fmt.printf("%sBlock_Stmt\n", prefix)
        for i := 0; i < len(n.statements); i += 1 {
            stmt := n.statements[i]
            print_node(stmt, indent + 1)
        }
    case .Return_Stmt:
        fmt.printf("%sReturn_Stmt\n", prefix)
        print_node(n.value, indent + 1)
    case .If_Stmt:
        fmt.printf("%sIf_Stmt\n", prefix)
        print_node(n.condition, indent + 1)
        print_node(n.body, indent + 1)
    case .For_Stmt:
        fmt.printf("%sFor_Stmt\n", prefix)
    case .Match_Stmt:
        fmt.printf("%sMatch_Stmt\n", prefix)
        print_node(n.match_value, indent + 1)
        for i := 0; i < len(n.match_patterns); i += 1 {
            fmt.printf("%s  Pattern:\n", prefix)
            print_node(n.match_patterns[i], indent + 2)
            fmt.printf("%s  Body:\n", prefix)
            print_node(n.cases[i], indent + 2)
        }
    case .Assign_Stmt:
        fmt.printf("%sAssign_Stmt: %s\n", prefix, n.target)
        print_node(n.value, indent + 1)
    case .Var_Decl:
        fmt.printf("%sVar_Decl: %s\n", prefix, n.name)
        print_node(n.value, indent + 1)
    case .Expr_Stmt:
        fmt.printf("%sExpr_Stmt\n", prefix)
        print_node(n.value, indent + 1)
    case .Import_Stmt:
        fmt.printf("%sImport: %s\n", prefix, n.import_path)
    case:
        fmt.printf("%s%v\n", prefix, n.kind)
    }
}
