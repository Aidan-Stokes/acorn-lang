package typecheck

import "../ast"
import "../common"
import "core:fmt"
import "core:strings"

Error :: struct {
    message: string,
    line:    int,
    column:  int,
}

errors: [dynamic]Error

Scope :: struct {
    vars:     map[string]^ast.Type_Info,
    parent:   ^Scope,
    struct_:  map[string]struct_fields,
    enum_:    map[string][]string,
    imports_: map[string][]^ast.Node,
}

struct_fields :: map[string]^ast.Type_Info

@(private)
current_scope: ^Scope
@(private)
root_scope: Scope
@(private)
global_consts: map[string]^ast.Type_Info
@(private)
generic_type_args: map[string]^ast.Type_Info

init :: proc() {
    clear(&errors)
    global_consts = make(map[string]^ast.Type_Info)
    generic_type_args = make(map[string]^ast.Type_Info)
    root_scope = Scope{
        vars = make(map[string]^ast.Type_Info),
        struct_ = make(map[string]struct_fields),
        enum_ = make(map[string][]string),
        imports_ = make(map[string][]^ast.Node),
    }
    current_scope = &root_scope
    setup_builtins()
}

destroy :: proc() {
    delete(global_consts)
    delete(generic_type_args)
    free_scope(&root_scope)
}

setup_builtins :: proc() {
    int_type := new(ast.Type_Info)
    int_type.kind = .Int
    int_type.name = "int"
    current_scope.vars["int"] = int_type

    str_type := new(ast.Type_Info)
    str_type.kind = .String
    str_type.name = "string"
    current_scope.vars["string"] = str_type

    bool_type := new(ast.Type_Info)
    bool_type.kind = .Bool
    bool_type.name = "bool"
    current_scope.vars["bool"] = bool_type

    f32_type := new(ast.Type_Info)
    f32_type.kind = .Named
    f32_type.name = "f32"
    current_scope.vars["f32"] = f32_type

    f64_type := new(ast.Type_Info)
    f64_type.kind = .Named
    f64_type.name = "f64"
    current_scope.vars["f64"] = f64_type

    void_type := new(ast.Type_Info)
    void_type.kind = .Void
    void_type.name = "void"
    current_scope.vars["void"] = void_type

    char_type := new(ast.Type_Info)
    char_type.kind = .Named
    char_type.name = "char"
    current_scope.vars["char"] = char_type

    uint_type := new(ast.Type_Info)
    uint_type.kind = .Named
    uint_type.name = "uint"
    current_scope.vars["uint"] = uint_type

    u8_type := new(ast.Type_Info)
    u8_type.kind = .Named
    u8_type.name = "u8"
    current_scope.vars["u8"] = u8_type

    u16_type := new(ast.Type_Info)
    u16_type.kind = .Named
    u16_type.name = "u16"
    current_scope.vars["u16"] = u16_type

    u32_type := new(ast.Type_Info)
    u32_type.kind = .Named
    u32_type.name = "u32"
    current_scope.vars["u32"] = u32_type

    u64_type := new(ast.Type_Info)
    u64_type.kind = .Named
    u64_type.name = "u64"
    current_scope.vars["u64"] = u64_type
}

free_scope :: proc(s: ^Scope) {
    delete(s.vars)
    for _, fields in s.struct_ {
        delete(fields)
    }
    delete(s.struct_)
    delete(s.enum_)
    delete(s.imports_)
}

get_module_name :: proc(import_path: string) -> string {
    if strings.has_prefix(import_path, "core:") {
        return strings.trim_prefix(import_path, "core:")
    }
    if strings.has_prefix(import_path, "lib:") {
        return strings.trim_prefix(import_path, "lib:")
    }
    for i := len(import_path) - 1; i >= 0; i -= 1 {
        if import_path[i] == '/' || import_path[i] == '\\' {
            return import_path[i+1:]
        }
    }
    idx := 0
    for i in 0..<len(import_path) {
        if import_path[i] == ':' {
            idx = i + 1
        }
    }
    if idx > 0 {
        return import_path[idx:]
    }
    for i := len(import_path) - 1; i >= 0; i -= 1 {
        if import_path[i] == '.' {
            return import_path[:i]
        }
    }
    return import_path
}

push_scope :: proc() {
    new_scope := new(Scope)
    new_scope.parent = current_scope
    new_scope.vars = make(map[string]^ast.Type_Info)
    new_scope.struct_ = make(map[string]struct_fields)
    new_scope.enum_ = make(map[string][]string)
    new_scope.imports_ = make(map[string][]^ast.Node)
    current_scope = new_scope
}

pop_scope :: proc() {
    if current_scope.parent != nil {
        free_scope(current_scope)
        current_scope = current_scope.parent
    }
}

add_error :: proc(message: string, line: int, column: int) {
    append(&errors, Error{message = message, line = line, column = column})
}

print_errors :: proc() {
    for err in errors {
        if err.line > 0 {
            common.colorf(.Red, "Type error at line %d, column %d: %s\n", err.line, err.column, err.message)
        } else {
            common.colorf(.Red, "Type error: %s\n", err.message)
        }
    }
}

has_errors :: proc() -> bool {
    return len(errors) > 0
}

lookup_var :: proc(name: string) -> ^ast.Type_Info {
    scope := current_scope
    for scope != nil {
        if t, ok := scope.vars[name]; ok {
            return t
        }
        scope = scope.parent
    }
    return nil
}

lookup_struct :: proc(name: string) -> struct_fields {
    scope := current_scope
    for scope != nil {
        if fields, ok := scope.struct_[name]; ok {
            return fields
        }
        scope = scope.parent
    }
    return nil
}

lookup_enum :: proc(name: string) -> ([]string, bool) {
    scope := current_scope
    for scope != nil {
        if variants, ok := scope.enum_[name]; ok {
            return variants, true
        }
        scope = scope.parent
    }
    return nil, false
}

lookup_global :: proc(name: string) -> ^ast.Type_Info {
    if t, ok := global_consts[name]; ok {
        return t
    }
    return nil
}

is_module_import :: proc(module_name: string) -> bool {
    scope := current_scope
    for scope != nil {
        if _, ok := scope.imports_[module_name]; ok {
            return true
        }
        scope = scope.parent
    }
    return false
}

is_numeric :: proc(t: ^ast.Type_Info) -> bool {
    if t == nil do return false
    return t.kind == .Int || t.kind == .Named && (t.name == "f32" || t.name == "f64")
}

is_comparable :: proc(a, b: ^ast.Type_Info) -> bool {
    if a == nil || b == nil do return false
    if a.kind == b.kind && a.name == b.name do return true
    return a.kind == b.kind || (is_numeric(a) && is_numeric(b))
}

types_equal :: proc(a, b: ^ast.Type_Info) -> bool {
    if a == nil || b == nil do return false
    if a.kind == b.kind && a.name == b.name do return true
    if a.kind == .Int && b.kind == .Named && is_integer_type_name(b.name) do return true
    if b.kind == .Int && a.kind == .Named && is_integer_type_name(a.name) do return true
    if a.kind == .Named && b.kind == .Named && a.name == b.name do return true
    if is_numeric(a) && is_numeric(b) do return true
    if a.kind == .Bool && b.kind == .Named && b.name == "bool" do return true
    if b.kind == .Bool && a.kind == .Named && a.name == "bool" do return true
    if a.kind == .Bool && b.kind == .Bool do return true
    if a.kind == .String && b.kind == .Named && b.name == "string" do return true
    if b.kind == .String && a.kind == .Named && a.name == "string" do return true
    if a.kind == .String && b.kind == .String do return true
    if a.kind == .Named && b.kind == .Named && is_pointer_type(a.name) && is_pointer_type(b.name) {
        return true
    }
    return false
}

is_pointer_type :: proc(name: string) -> bool {
    return len(name) > 0 && name[0] == '^'
}

is_integer_type_name :: proc(name: string) -> bool {
    return name == "int" || name == "uint" || name == "i32" || name == "i16" || 
           name == "i8" || name == "u8" || name == "u16" || name == "u32" || 
           name == "u64" || name == "i64" || name == "byte" || name == "char" || name == "rune"
}

get_line :: proc(node: ^ast.Node) -> int {
    return 0
}

@(private)
module_members: map[string]map[string]^ast.Type_Info

check_program :: proc(prog: ^ast.Program) -> bool {
    init()
    module_members = make(map[string]map[string]^ast.Type_Info)
    defer {
        for _, members in module_members {
            delete(members)
        }
        delete(module_members)
    }
    for decl in prog.declarations {
        if decl.kind == .Import_Stmt {
            check_node(decl)
        }
    }
    for decl in prog.declarations {
        if decl.kind == .Const_Decl {
            check_node(decl)
        }
    }
    for decl in prog.declarations {
        if decl.kind != .Import_Stmt && decl.kind != .Const_Decl {
            check_node(decl)
        }
    }
    return !has_errors()
}

check_node :: proc(node: ^ast.Node) -> ^ast.Type_Info {
    if node == nil do return nil

    #partial switch node.kind {
    case .Int_Literal:
        t := new(ast.Type_Info)
        t.kind = .Int
        t.name = "int"
        node.type = t
        return t

    case .Float_Literal:
        t := new(ast.Type_Info)
        t.kind = .Named
        t.name = "f64"
        node.type = t
        return t

    case .String_Literal:
        t := new(ast.Type_Info)
        t.kind = .String
        t.name = "string"
        node.type = t
        return t

    case .Char_Literal:
        t := new(ast.Type_Info)
        t.kind = .Named
        t.name = "char"
        node.type = t
        return t

    case .Bool_Literal:
        t := new(ast.Type_Info)
        t.kind = .Bool
        t.name = "bool"
        node.type = t
        return t

    case .Ident:
        t := lookup_var(node.name)
        if t == nil {
            t = lookup_global(node.name)
        }
        if t == nil {
            if _, ok := lookup_enum(node.name); ok {
                t = new(ast.Type_Info)
                t.kind = .Named
                t.name = node.name
            } else {
                add_error(fmt.tprintf("Undefined variable: %s", node.name), get_line(node), 0)
                t = new(ast.Type_Info)
                t.kind = .Invalid
                t.name = "<unknown>"
            }
        }
        node.type = t
        return t

    case .Binary_Expr:
        left := check_node(node.left)
        right := check_node(node.right)

        if node.operator == "==" || node.operator == "!=" ||
           node.operator == "<" || node.operator == "<=" ||
           node.operator == ">" || node.operator == ">=" {
            if !is_comparable(left, right) {
                add_error(
                    fmt.tprintf("Cannot compare %s and %s", type_name(left), type_name(right)),
                    get_line(node), 0
                )
            }
            t := new(ast.Type_Info)
            t.kind = .Bool
            t.name = "bool"
            node.type = t
            return t
        }

        if node.operator == "&&" || node.operator == "||" {
            if !types_equal(left, right) || left.kind != .Bool {
                add_error(
                    fmt.tprintf("Logical operators require bool operands, got %s and %s",
                        type_name(left), type_name(right)),
                    get_line(node), 0
                )
            }
            t := new(ast.Type_Info)
            t.kind = .Bool
            t.name = "bool"
            node.type = t
            return t
        }

        if left != nil && right != nil && !is_numeric(left) && !is_numeric(right) && left.kind != .Invalid && right.kind != .Invalid {
            add_error(
                fmt.tprintf("Arithmetic operators require numeric operands, got %s and %s",
                    type_name(left), type_name(right)),
                get_line(node), 0
            )
        }

        result_name := "int"
        if left.kind == .Named && (left.name == "f32" || left.name == "f64") {
            result_name = left.name
        }

        t := new(ast.Type_Info)
        t.kind = .Named
        t.name = result_name
        node.type = t
        return t

    case .Unary_Expr:
        operand := check_node(node.operand)

        if node.operator == "!" {
            if operand.kind != .Bool {
                add_error(
                    fmt.tprintf("Logical NOT requires bool operand, got %s", type_name(operand)),
                    get_line(node), 0
                )
            }
            t := new(ast.Type_Info)
            t.kind = .Bool
            t.name = "bool"
            node.type = t
            return t
        }

        if node.operator == "-" {
            if !is_numeric(operand) {
                add_error(
                    fmt.tprintf("Unary minus requires numeric operand, got %s", type_name(operand)),
                    get_line(node), 0
                )
            }
            node.type = operand
            return operand
        }

        if node.operator == "&" {
            ptr_type := new(ast.Type_Info)
            ptr_type.kind = .Named
            ptr_type.name = strings.concatenate([]string{"^", operand.name})
            node.type = ptr_type
            return ptr_type
        }

        if node.operator == "^" {
            if operand != nil && operand.kind == .Named {
                name := operand.name
                if len(name) > 1 && name[0] == '^' {
                    base_name := name[1:]
                    base_type := new(ast.Type_Info)
                    base_type.kind = .Named
                    base_type.name = base_name
                    node.type = base_type
                    return base_type
                }
            }
            node.type = operand
            return operand
        }

        node.type = operand
        return operand

    case .Call_Expr:
        // Handle generic function calls - check if callee is a generic function
        if node.callee != nil && node.callee.kind == .Ident {
            func_name := node.callee.name
            
            fn_type := lookup_var(func_name)
            
            // Handle explicit generic args: abs<int>(5)
            if fn_type != nil && fn_type.kind == .Fn && len(node.callee.generic_args) > 0 {
                for i := 0; i < len(node.callee.generic_args) && i < len(fn_type.generic_params); i += 1 {
                    arg_type := make_type_info(node.callee.generic_args[i])
                    param_name := fn_type.generic_params[i]
                    generic_type_args[param_name] = arg_type

                    if len(fn_type.where_constraints) > 0 {
                        constraint := fn_type.where_constraints[0]
                        if !type_satisfies_constraint(arg_type, constraint) {
                            add_error(fmt.tprintf("Type '%s' does not satisfy constraint '%s'", arg_type.name, constraint), get_line(node), 0)
                        }
                    }
                }
            }
            
            // Handle implicit generic type inference from arguments
            if fn_type != nil && fn_type.kind == .Fn && len(fn_type.generic_params) > 0 && len(node.arguments) > 0 {
                first_arg := node.arguments[0]
                if first_arg.type != nil {
                    inferred_type := new(ast.Type_Info)
                    inferred_type^ = first_arg.type^
                    generic_type_args[fn_type.generic_params[0]] = inferred_type
                }
            }
        }
        
        for arg in node.arguments {
            check_node(arg)
        }
        t := new(ast.Type_Info)
        t.kind = .Named
        t.name = "int"
        node.type = t
        return t

    case .Array_Literal:
        for elem in node.elements {
            check_node(elem)
        }
        t := new(ast.Type_Info)
        t.kind = .Array
        if len(node.elements) > 0 {
            t.element_type = node.elements[0].type
        }
        node.type = t
        return t

    case .Index_Expr:
        check_node(node.object)
        check_node(node.left)
        if node.object.type != nil && node.object.type.kind == .Array {
            node.type = node.object.type.element_type
            return node.object.type.element_type
        }
        t := new(ast.Type_Info)
        t.kind = .Int
        node.type = t
        return t

    case .Member_Expr:
        if node.object.kind == .Ident {
            module_name := node.object.name
            if is_module_import(module_name) {
                if const_info := lookup_global(node.field); const_info != nil {
                    node.type = const_info
                    return const_info
                }
            }
        }
        check_node(node.object)
        if node.object.type != nil && node.object.type.kind == .Named {
            fields := lookup_struct(node.object.type.name)
            if fields != nil {
                if field_type, ok := fields[node.field]; ok {
                    node.type = field_type
                    return field_type
                }
            }
            if variants, ok := lookup_enum(node.object.type.name); ok {
                for v in variants {
                    if v == node.field {
                        t := new(ast.Type_Info)
                        t.kind = .Int
                        t.name = "int"
                        node.type = t
                        return t
                    }
                }
            }
        }
        return nil

    case .Struct_Literal:
        fields := lookup_struct(node.name)
        if fields == nil {
            add_error(fmt.tprintf("Unknown struct type: %s", node.name), get_line(node), 0)
        }
        for f in node.fields {
            check_node(f.value)
            if fields != nil {
                if expected, ok := fields[f.name]; ok {
                    expected_name := type_name(expected)
                    is_generic := len(expected_name) == 1 && expected_name[0] >= 'A' && expected_name[0] <= 'Z'
                    if !is_generic {
                        if !types_equal(expected, f.value.type) {
                            add_error(
                                fmt.tprintf("Field '%s' expected type %s, got %s",
                                    f.name, type_name(expected), type_name(f.value.type)),
                                get_line(node), 0
                            )
                        }
                    }
                }
            }
        }
        t := new(ast.Type_Info)
        t.kind = .Named
        t.name = node.name
        node.type = t
        return t

    case .Pipe_Expr:
        left := check_node(node.pipe_left)
        check_node(node.pipe_right)
        node.type = left
        return left

    case .Fn_Decl:
        generic_params := node.generic_params
        
        if len(generic_params) > 0 {
            for param in generic_params {
                t := new(ast.Type_Info)
                t.kind = .Named
                t.name = param
                generic_type_args[param] = t
            }
        }

        return_type := make_fn_return_type(node.return_type)
        t := new(ast.Type_Info)
        t.kind = .Fn
        t.name = node.name
        t.return_type = return_type
        t.generic_params = generic_params
        current_scope.vars[node.name] = t

        push_scope()
        defer pop_scope()

        for p in node.params {
            ptype := make_type_info(p.type)
            current_scope.vars[p.name] = ptype
        }

        check_node(node.body)
        
        if len(generic_params) > 0 {
            clear(&generic_type_args)
        }
        
        return t

    case .Struct_Decl:
        generic_params := node.generic_params
        
        fields := make(map[string]^ast.Type_Info)
        for f in node.fields {
            fields[f.name] = make_type_info(f.type)
        }
        current_scope.struct_[node.name] = fields
        
        return nil

    case .Enum_Decl:
        variants := make([]string, len(node.enum_variants))
        for i := 0; i < len(node.enum_variants); i += 1 {
            variants[i] = node.enum_variants[i].name
        }
        current_scope.enum_[node.name] = variants
        return nil

    case .Block_Stmt:
        push_scope()
        defer pop_scope()
        for stmt in node.statements {
            check_node(stmt)
        }
        return nil

    case .Return_Stmt:
        if node.value != nil {
            check_node(node.value)
        }
        return nil

    case .If_Stmt:
        check_node(node.condition)
        check_node(node.else_branch)
        if node.else_branch != nil {
            check_node(node.else_branch)
        }
        return nil

    case .For_Stmt:
        check_node(node.body)
        return nil

    case .For_In_Stmt:
        int_type := new(ast.Type_Info)
        int_type.kind = .Int
        int_type.name = "int"
        current_scope.vars[node.for_var] = int_type
        check_node(node.body)
        return nil

    case .For_Condition_Stmt:
        check_node(node.condition)
        check_node(node.body)
        return nil

    case .Match_Stmt:
        check_node(node.match_value)
        for pattern in node.match_patterns {
            check_node(pattern)
        }
        for body in node.cases {
            check_node(body)
        }
        return nil

    case .Assign_Stmt:
        value_type := check_node(node.value)
        existing := lookup_var(node.target)
        if existing == nil {
            current_scope.vars[node.target] = value_type
        }
        return nil

    case .Var_Decl:
        vtype := make_type_info(node.return_type)
        current_scope.vars[node.name] = vtype
        if node.value != nil {
            value_type := check_node(node.value)
            if vtype.kind != .Invalid && !types_equal(vtype, node.value.type) && node.value.type.kind != .Invalid {
                add_error(
                    fmt.tprintf("Variable '%s' of type %s cannot be assigned %s",
                        node.name, type_name(vtype), type_name(node.value.type)),
                    get_line(node), 0
                )
            }
        }
        return nil

    case .Const_Decl:
        if node.value != nil {
            check_node(node.value)
        }
        
        ctype: ^ast.Type_Info
        if node.return_type.name != "" {
            ctype = make_type_info(node.return_type)
        } else if node.value != nil {
            ctype = node.value.type
        }
        if ctype != nil {
            global_consts[node.name] = ctype
        }
        return nil

    case .Break_Stmt, .Continue_Stmt, .Expr_Stmt:
        if node.kind == .Expr_Stmt && node.value != nil {
            check_node(node.value)
        }
        return nil

    case .Import_Stmt:
        import_path := node.import_path
        module_name := get_module_name(import_path)
        if module_name != "" {
            current_scope.imports_[module_name] = nil
            if _, exists := module_members[module_name]; !exists {
                module_members[module_name] = make(map[string]^ast.Type_Info)
            }
        }
        return nil

    case .Invalid:
        return nil
    }

    return nil
}

make_type_info :: proc(t: ast.Type) -> ^ast.Type_Info {
    info := new(ast.Type_Info)
    
    if t.is_array {
        info.kind = .Array
        info.element_type = make_type_info(ast.Type{name = t.base_type})
    } else if t.pointer_level > 0 {
        info.kind = .Named
        info.name = strings.concatenate([]string{"^", t.name})
    } else {
        if arg, ok := generic_type_args[t.name]; ok {
            info.kind = arg.kind
            info.name = arg.name
        } else {
            info.kind = .Named
            info.name = t.name
        }
    }
    return info
}

make_fn_return_type :: proc(t: ast.Type) -> ^ast.Type_Info {
    return substitute_generic_types(make_type_info(t))
}

substitute_generic_types :: proc(t: ^ast.Type_Info) -> ^ast.Type_Info {
    if t == nil do return nil
    
    if t.kind == .Named {
        if arg, ok := generic_type_args[t.name]; ok {
            return arg
        }
    }
    
    if t.element_type != nil {
        t.element_type = substitute_generic_types(t.element_type)
    }
    
    return t
}

substitute_type :: proc(t: ast.Type) -> ast.Type {
    result := t
    if t.is_generic && len(t.generic_args) > 0 && len(t.generic_params) > 0 {
        for i := 0; i < len(t.generic_params); i += 1 {
            if i < len(t.generic_args) {
                arg_type := make_type_info(t.generic_args[i])
                generic_type_args[t.generic_params[i]] = arg_type
            }
        }
        result.name = t.base_type
        result.is_generic = false
        result.generic_args = nil
    } else if arg, ok := generic_type_args[t.name]; ok {
        result.name = arg.name
    }
    return result
}

type_name :: proc(t: ^ast.Type_Info) -> string {
    if t == nil do return "<nil>"
    switch t.kind {
    case .Invalid:
        return "<invalid>"
    case .Int:
        return "int"
    case .String:
        return "string"
    case .Bool:
        return "bool"
    case .Void:
        return "void"
    case .Named:
        return t.name
    case .Array:
        if t.element_type != nil {
            elem_name := type_name(t.element_type)
            if elem_name != "" {
                return strings.concatenate([]string{"[]", elem_name})
            }
        }
        return "[]?"
    case .Fn:
        return "fn"
    case:
        return "<unknown>"
    }
}

type_satisfies_constraint :: proc(t: ^ast.Type_Info, constraint: string) -> bool {
    if constraint == "Numeric" {
        type_name_str := type_name(t)
        if type_name_str == "int" || type_name_str == "i32" || type_name_str == "i64" ||
           type_name_str == "f32" || type_name_str == "f64" {
            return true
        }
        return false
    }
    if constraint == "Comparable" {
        type_name_str := type_name(t)
        if type_name_str == "int" || type_name_str == "i32" || type_name_str == "i64" ||
           type_name_str == "f32" || type_name_str == "f64" || type_name_str == "string" {
            return true
        }
        return false
    }
    return true
}
