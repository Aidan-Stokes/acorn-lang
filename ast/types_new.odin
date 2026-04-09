package ast

// New type system additions - Phase 1 of AST refactoring
// These provide type information that can be used alongside the legacy Node struct

import "core:mem"

Source_Location :: struct {
    file:   string,
    line:   int,
    column: int,
}

Type_Kind_New :: enum {
    Invalid,
    Int,
    Uint,
    String,
    Bool,
    Float,
    Void,
    Char,
    Byte,
    Pointer,
    Array,
    Function,
    Struct,
    Enum,
    Generic,
    Module,
    Named,
}

Type_New :: union {
    Primitive_Type_New,
    Pointer_Type_New,
    Array_Type_New,
    Function_Type_New,
    Struct_Type_New,
    Enum_Type_New,
    Generic_Type_New,
    Named_Type_New,
}

Primitive_Type_New :: struct {
    kind: Type_Kind_New,
}

Pointer_Type_New :: struct {
    pointee: ^Type_New,
}

Array_Type_New :: struct {
    element: ^Type_New,
    size:    int,
}

Function_Type_New :: struct {
    params:      []^Type_New,
    return_type: ^Type_New,
}

Struct_Type_New :: struct {
    name:   string,
    fields: []Struct_Field_New,
}

Struct_Field_New :: struct {
    name: string,
    type: ^Type_New,
}

Enum_Type_New :: struct {
    name:     string,
    variants: []string,
}

Generic_Type_New :: struct {
    name:        string,
    constraints: []string,
}

Named_Type_New :: struct {
    name: string,
    base: ^Type_New,
}

Type_Info_New :: struct {
    type:        ^Type_New,
    is_constant: bool,
}

// Builder procedures for new types
make_primitive_type :: proc(kind: Type_Kind_New) -> ^Type_New {
    t := new(Type_New)
    t^ = Primitive_Type_New{kind = kind}
    return t
}

make_int_type :: proc() -> ^Type_New {
    return make_primitive_type(.Int)
}

make_uint_type :: proc() -> ^Type_New {
    return make_primitive_type(.Uint)
}

make_string_type :: proc() -> ^Type_New {
    return make_primitive_type(.String)
}

make_bool_type :: proc() -> ^Type_New {
    return make_primitive_type(.Bool)
}

make_float_type :: proc() -> ^Type_New {
    return make_primitive_type(.Float)
}

make_void_type :: proc() -> ^Type_New {
    return make_primitive_type(.Void)
}

make_char_type :: proc() -> ^Type_New {
    return make_primitive_type(.Char)
}

make_pointer_type :: proc(pointee: ^Type_New) -> ^Type_New {
    t := new(Type_New)
    t^ = Pointer_Type_New{pointee = pointee}
    return t
}

make_array_type :: proc(element: ^Type_New, size: int) -> ^Type_New {
    t := new(Type_New)
    t^ = Array_Type_New{element = element, size = size}
    return t
}

make_struct_type :: proc(name: string, fields: []Struct_Field_New) -> ^Type_New {
    t := new(Type_New)
    t^ = Struct_Type_New{name = name, fields = fields}
    return t
}

make_function_type :: proc(params: []^Type_New, return_type: ^Type_New) -> ^Type_New {
    t := new(Type_New)
    t^ = Function_Type_New{params = params, return_type = return_type}
    return t
}

make_enum_type :: proc(name: string, variants: []string) -> ^Type_New {
    t := new(Type_New)
    t^ = Enum_Type_New{name = name, variants = variants}
    return t
}

make_named_type :: proc(name: string, base: ^Type_New) -> ^Type_New {
    t := new(Type_New)
    t^ = Named_Type_New{name = name, base = base}
    return t
}

// Type to string for debugging
type_to_string :: proc(t: ^Type_New) -> string {
    if t == nil {
        return "nil"
    }
    
    if pt, ok := t.(Primitive_Type_New); ok {
        #partial switch pt.kind {
        case .Int: return "int"
        case .Uint: return "uint"
        case .String: return "string"
        case .Bool: return "bool"
        case .Float: return "float"
        case .Void: return "void"
        case .Char: return "char"
        case .Byte: return "byte"
        case .Invalid: return "invalid"
        case .Named: return "named"
        }
        return "unknown"
    }
    
    if _, ok := t.(Pointer_Type_New); ok {
        return "pointer"
    }
    if _, ok := t.(Array_Type_New); ok {
        return "array"
    }
    if ft, ok := t.(Function_Type_New); ok {
        return "function"
    }
    if st, ok := t.(Struct_Type_New); ok {
        return st.name
    }
    if et, ok := t.(Enum_Type_New); ok {
        return et.name
    }
    if gt, ok := t.(Generic_Type_New); ok {
        return gt.name
    }
    if nt, ok := t.(Named_Type_New); ok {
        return nt.name
    }
    
    return "unknown"
}

// Constraints for generics
Constraint_New :: enum {
    Equatable,
    Comparable,
    Addable,
    Subtractable,
    Multipliable,
    Divisible,
    Negatable,
    Showable,
    Integral,
    Floating,
    Byte_Equatable,
}

check_constraint :: proc(t: ^Type_New, constraint: Constraint_New) -> bool {
    if t == nil {
        return false
    }
    
    if pt, ok := t.(Primitive_Type_New); ok {
        #partial switch pt.kind {
        case .Int, .Uint:
            #partial switch constraint {
            case .Integral, .Equatable, .Comparable, .Addable, .Subtractable, .Multipliable, .Divisible, .Negatable, .Showable:
                return true
            case .Floating:
                return false
            case .Byte_Equatable:
                return pt.kind == .Uint
            }
        case .Float:
            #partial switch constraint {
            case .Floating, .Equatable, .Comparable, .Addable, .Subtractable, .Multipliable, .Divisible, .Negatable, .Showable:
                return true
            case .Integral:
                return false
            }
        case .Bool:
            #partial switch constraint {
            case .Equatable, .Showable:
                return true
            }
        case .String:
            #partial switch constraint {
            case .Equatable, .Comparable, .Showable:
                return true
            }
        case .Char, .Byte:
            #partial switch constraint {
            case .Equatable, .Comparable, .Integral, .Byte_Equatable, .Showable:
                return true
            }
        }
    }
    
    return false
}

// Migration helpers - convert between old and new type systems

// Convert old ast.Type to new Type_New
convert_from_old_type :: proc(t: ^Type) -> ^Type_New {
    if t == nil {
        return nil
    }
    
    if t.is_array {
        elem := convert_from_old_type(&Type{name = t.base_type})
        return make_array_type(elem, t.array_size)
    }
    
    if t.pointer_level > 0 {
        pointee := convert_from_old_type(&Type{name = t.base_type})
        for i := 1; i < t.pointer_level; i += 1 {
            pointee = make_pointer_type(pointee)
        }
        return pointee
    }
    
    if t.is_generic {
        return make_named_type(t.name, nil)
    }
    
    switch t.base_type {
    case "int", "i32":
        return make_int_type()
    case "uint", "u32", "u64":
        return make_uint_type()
    case "string":
        return make_string_type()
    case "bool":
        return make_bool_type()
    case "f32", "f64", "float":
        return make_float_type()
    case "void":
        return make_void_type()
    case "char":
        return make_char_type()
    case "byte":
        return make_primitive_type(.Byte)
    case:
        return make_named_type(t.base_type, nil)
    }
}

// Convert old ast.Type_Info to new Type_New
convert_from_type_info :: proc(ti: ^Type_Info) -> ^Type_New {
    if ti == nil {
        return nil
    }
    
    #partial switch ti.kind {
    case .Int:
        return make_int_type()
    case .String:
        return make_string_type()
    case .Bool:
        return make_bool_type()
    case .Void:
        return make_void_type()
    case .Named:
        return make_named_type(ti.name, nil)
    case .Array:
        if ti.element_type != nil {
            elem := convert_from_type_info(ti.element_type)
            return make_array_type(elem, 0)
        }
        return make_array_type(make_int_type(), 0)
    case .Fn:
        return make_function_type(nil, nil)
    }
    
    return nil
}