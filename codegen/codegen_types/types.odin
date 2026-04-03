package codegen_types

import "core:mem"
import "core:strings"
import "../../ast"
import llvm "../../bindings/llvm"

Codegen_State :: struct {
	struct_types:     map[string]llvm.TypeRef,
	struct_fields:    map[string][]string,
	enum_variants:    map[string]map[string]int,
	global_consts:    map[string]llvm.ValueRef,
	fn_types:         map[string]Fn_Info,
	generic_type_map: map[string]string,
}

Fn_Info :: struct {
	ret_type:      llvm.TypeRef,
	param_types:   []llvm.TypeRef,
	generic_params: []string,
}

init_state :: proc() -> Codegen_State {
	return Codegen_State {
		struct_types     = make(map[string]llvm.TypeRef),
		struct_fields    = make(map[string][]string),
		enum_variants    = make(map[string]map[string]int),
		global_consts    = make(map[string]llvm.ValueRef),
		fn_types         = make(map[string]Fn_Info),
		generic_type_map = make(map[string]string),
	}
}

destroy_state :: proc(state: ^Codegen_State) {
	delete(state.struct_types)
	for key in state.struct_fields {
		delete(state.struct_fields[key])
	}
	delete(state.struct_fields)
	for key in state.enum_variants {
		delete(state.enum_variants[key])
	}
	delete(state.enum_variants)
	delete(state.global_consts)
	for key in state.fn_types {
		delete(state.fn_types[key].param_types)
	}
	delete(state.fn_types)
	delete(state.generic_type_map)
}

get_llvm_type :: proc(state: ^Codegen_State, type_name: string) -> llvm.TypeRef {
	switch type_name {
	case "int":
		return llvm.LLVMInt32Type()
	case "u":
		return llvm.LLVMInt32Type()
	case "i32":
		return llvm.LLVMInt32Type()
	case "i16":
		return llvm.LLVMInt16Type()
	case "i8":
		return llvm.LLVMInt8Type()
	case "byte":
		return llvm.LLVMInt8Type()
	case "u8":
		return llvm.LLVMInt8Type()
	case "u16":
		return llvm.LLVMInt16Type()
	case "u32":
		return llvm.LLVMInt32Type()
	case "i64":
		return llvm.LLVMInt64Type()
	case "u64":
		return llvm.LLVMInt64Type()
	case "f32":
		return llvm.LLVMDoubleType()
	case "f64":
		return llvm.LLVMDoubleType()
	case "bool":
		return llvm.LLVMInt1Type()
	case "char", "rune":
		return llvm.LLVMInt32Type()
	case "string":
		return llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
	case "str":
		return llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
	case:
		if struct_ty, ok := state.struct_types[type_name]; ok {
			return struct_ty
		}
		if resolved, ok := state.generic_type_map[type_name]; ok {
			return get_llvm_type(state, resolved)
		}
	}
	return llvm.LLVMInt32Type()
}

get_llvm_type_for_value :: proc(node: ^ast.Node) -> llvm.TypeRef {
	if node == nil do return llvm.LLVMInt32Type()
	#partial switch node.kind {
	case .Int_Literal:
		return llvm.LLVMInt32Type()
	case .Float_Literal:
		return llvm.LLVMDoubleType()
	case .Bool_Literal:
		return llvm.LLVMInt1Type()
	case .String_Literal:
		return llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
	}
	return llvm.LLVMInt32Type()
}

get_llvm_const_value :: proc(module: llvm.ModuleRef, state: ^Codegen_State, node: ^ast.Node) -> llvm.ValueRef {
	if node == nil do return nil
	#partial switch node.kind {
	case .Int_Literal:
		return llvm.LLVMConstInt(llvm.LLVMInt32Type(), u64(node.int_value), 0)
	case .Float_Literal:
		return llvm.LLVMConstReal(llvm.LLVMDoubleType(), node.float_value)
	case .Bool_Literal:
		b := u64(0)
		if node.bool_value { b = 1 }
		return llvm.LLVMConstInt(llvm.LLVMInt1Type(), b, 0)
	case .String_Literal:
		str_c := strings.clone_to_cstring(node.string_value)
		defer delete(str_c)
		return llvm.LLVMAddGlobal(module, llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0), str_c)
	case .Ident:
		if gv, ok := state.global_consts[node.name]; ok {
			return llvm.LLVMGetInitializer(gv)
		}
	}
	return nil
}

generate_struct :: proc(state: ^Codegen_State, module: llvm.ModuleRef, node: ^ast.Node) {
	struct_name := node.name
	name_c := strings.clone_to_cstring(struct_name)
	defer delete(name_c)

	struct_ty := llvm.LLVMStructCreateNamed(llvm.LLVMGetGlobalContext(), name_c)
	state.struct_types[struct_name] = struct_ty

	if node.fields != nil && len(node.fields) > 0 {
		elem_types := make([]llvm.TypeRef, len(node.fields))
		defer delete(elem_types)
		field_names := make([]string, len(node.fields))
		for i := 0; i < len(node.fields); i += 1 {
			field_type_name := node.fields[i].type.name
			elem_types[i] = get_llvm_type(state, field_type_name)
			field_names[i] = strings.clone(node.fields[i].name)
		}
		llvm.LLVMStructSetBody(struct_ty, raw_data(elem_types), uint(len(elem_types)), 0)
		state.struct_fields[struct_name] = field_names
	}
}

generate_enum :: proc(state: ^Codegen_State, node: ^ast.Node) {
	enum_name := node.name
	variant_map := make(map[string]int)
	for i := 0; i < len(node.enum_variants); i += 1 {
		variant_map[node.enum_variants[i].name] = node.enum_variants[i].value
	}
	state.enum_variants[enum_name] = variant_map
}

generate_const :: proc(state: ^Codegen_State, module: llvm.ModuleRef, node: ^ast.Node) {
	name := node.name
	name_c := strings.clone_to_cstring(name)
	defer delete(name_c)

	llvm_ty: llvm.TypeRef
	if node.return_type.name != "" {
		llvm_ty = get_llvm_type(state, node.return_type.name)
	} else if node.value != nil {
		llvm_ty = get_llvm_type_for_value(node.value)
	} else {
		llvm_ty = llvm.LLVMInt32Type()
	}

	global_var := llvm.LLVMAddGlobal(module, llvm_ty, name_c)
	llvm.LLVMSetGlobalConstant(global_var, true)

	if node.value != nil {
		init_val := get_llvm_const_value(module, state, node.value)
		if init_val != nil {
			llvm.LLVMSetInitializer(global_var, init_val)
		}
	}

	state.global_consts[name] = global_var
}

generate_global :: proc(state: ^Codegen_State, module: llvm.ModuleRef, node: ^ast.Node) {
	name := node.name
	name_c := strings.clone_to_cstring(name)
	defer delete(name_c)

	llvm_ty: llvm.TypeRef
	if node.return_type.name != "" {
		llvm_ty = get_llvm_type(state, node.return_type.name)
	} else {
		llvm_ty = llvm.LLVMInt32Type()
	}

	global_var := llvm.LLVMAddGlobal(module, llvm_ty, name_c)

	if node.value != nil {
		init_val := get_llvm_const_value(module, state, node.value)
		if init_val != nil {
			llvm.LLVMSetInitializer(global_var, init_val)
		}
	}

	state.global_consts[name] = global_var
}

generate_global_assign :: proc(state: ^Codegen_State, module: llvm.ModuleRef, node: ^ast.Node) {
	name := node.target
	name_c := strings.clone_to_cstring(name)
	defer delete(name_c)

	llvm_ty: llvm.TypeRef
	if gv, ok := state.global_consts[name]; ok {
		llvm_ty = llvm.LLVMTypeOf(gv)
	} else {
		llvm_ty = llvm.LLVMInt32Type()
	}

	global_var := llvm.LLVMAddGlobal(module, llvm_ty, name_c)

	if node.value != nil {
		init_val := get_llvm_const_value(module, state, node.value)
		if init_val != nil {
			llvm.LLVMSetInitializer(global_var, init_val)
		}
	}

	state.global_consts[name] = global_var
}

find_struct_field_index :: proc(state: ^Codegen_State, struct_name: string, field_name: string) -> int {
	if struct_name == "" {
		return -1
	}
	if fields, ok := state.struct_fields[struct_name]; ok {
		for i in 0..<len(fields) {
			if fields[i] == field_name {
				return i
			}
		}
	}
	return -1
}

find_enum_variant_value :: proc(state: ^Codegen_State, enum_name: string, variant_name: string) -> (value: int, found: bool) {
	if variant_map, ok := state.enum_variants[enum_name]; ok {
		if val, ok := variant_map[variant_name]; ok {
			return val, true
		}
	}
	return 0, false
}
