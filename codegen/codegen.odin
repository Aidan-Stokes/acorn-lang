package codegen

import "../ast"
import "../common"
import "../imports"
import "../lexer"
import llvm "../bindings/llvm"
import "../parser"
import "../typecheck"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"

import ct "codegen_types"
import cu "codegen_utils"

foreign import libc "system:c"

foreign libc {
	@(link_name="system")
	c_system :: proc(cmd: cstring) -> c.int ---
}

@(private)
run_command :: proc(cmd: string) -> int {
	cmd_cstr, _ := strings.clone_to_cstring(cmd)
	defer delete(cmd_cstr)
	return int(c_system(cmd_cstr))
}

LLVMIntEQ :: cu.LLVMIntEQ
LLVMIntNE :: cu.LLVMIntNE
LLVMIntSGT :: cu.LLVMIntSGT
LLVMIntSGE :: cu.LLVMIntSGE
LLVMIntSLT :: cu.LLVMIntSLT
LLVMIntSLE :: cu.LLVMIntSLE

struct_types: map[string]llvm.TypeRef
struct_fields: map[string][]string
enum_variants: map[string]map[string]int
global_consts: map[string]llvm.ValueRef

Fn_Info :: struct {
	ret_type: llvm.TypeRef,
	param_types: []llvm.TypeRef,
	generic_params: []string,
}

fn_types: map[string]Fn_Info

generic_type_map: map[string]string

// Minimal value typing for LLVM generation.
ValueInfo :: struct {
	val: llvm.ValueRef,
	ty:  llvm.TypeRef,
	base_type: string,   // For pointer types: the underlying type name (e.g., "float")
	struct_type: string, // For struct values: the struct type name
}

VarInfo :: struct {
	ptr: llvm.ValueRef, // alloca pointer
	ty:  llvm.TypeRef, // element type
}

Var_Entry :: struct {
	name: string,
	ptr: llvm.ValueRef,
	ty: llvm.TypeRef,
	base_type: string,   // For pointers: the underlying type name (e.g., "int", "float")
	struct_type: string, // For struct variables: the struct type name
}

CompilerCtx :: struct {
	module:       llvm.ModuleRef,
	builder:      llvm.BuilderRef,
	fn:           llvm.ValueRef,
	fn_ret_type:  llvm.TypeRef,
	fn_ret_name:  string,
	break_bb:     llvm.BasicBlockRef,
	continue_bb:  llvm.BasicBlockRef,
	allocator:    mem.Allocator,
	vars: #soa [dynamic]Var_Entry,
}

		add_var :: proc(ctx: ^CompilerCtx, name: string, ptr: llvm.ValueRef, ty: llvm.TypeRef, base_type := "", struct_type := "") {
	for i in 0..<len(ctx.vars) {
		if ctx.vars[i].name == name {
			ctx.vars[i].ptr = ptr
			ctx.vars[i].ty = ty
			ctx.vars[i].base_type = base_type
			ctx.vars[i].struct_type = struct_type
			return
		}
	}
	append(&ctx.vars, Var_Entry{
		name = name,
		ptr = ptr,
		ty = ty,
		base_type = base_type,
		struct_type = struct_type,
	})
}

	find_var :: proc(ctx: ^CompilerCtx, name: string) -> (ptr: llvm.ValueRef, ty: llvm.TypeRef, base_type: string, struct_type: string, found: bool) {
	for i := len(ctx.vars) - 1; i >= 0; i -= 1 {
		entry := ctx.vars[i]
		if entry.name == name {
			return entry.ptr, entry.ty, entry.base_type, entry.struct_type, true
		}
	}
	return nil, nil, "", "", false
}

	find_struct_field_index :: proc(struct_name: string, field_name: string) -> int {
	if struct_name == "" {
		return -1
	}
	if fields, ok := struct_fields[struct_name]; ok {
		for i in 0..<len(fields) {
			if fields[i] == field_name {
				return i
			}
		}
	}
	return -1
}

find_enum_variant_value :: proc(enum_name: string, variant_name: string) -> (value: int, found: bool) {
	if variant_map, ok := enum_variants[enum_name]; ok {
		if val, ok := variant_map[variant_name]; ok {
			return val, true
		}
	}
	return 0, false
}

verify_module :: proc(module: llvm.ModuleRef) -> bool {
	return cu.verify_module(module)
}

get_llvm_type :: proc(type_name: string) -> llvm.TypeRef {
	switch type_name {
	case "int":
		return llvm.LLVMInt64Type()  // usize_t equivalent
	case "u":
		return llvm.LLVMInt64Type()  // platform unsigned (u64 on 64-bit)
	case "i32":
		return llvm.LLVMInt32Type()
	case "i16":
		return llvm.LLVMInt16Type()
	case "i8":
		return llvm.LLVMInt8Type()
	case "byte":
		return llvm.LLVMInt8Type()  // alias for u8
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
		return llvm.LLVMInt32Type()  // rune is unicode, 32-bit
	case "string":
		return llvm.LLVMInt64Type()  // for now, pointer as int64
	case "str":
		return llvm.LLVMInt64Type()  // legacy alias
	case:
		if struct_ty, ok := struct_types[type_name]; ok {
			return struct_ty
		}
		// Check generic type mapping
		if resolved, ok := generic_type_map[type_name]; ok {
			return get_llvm_type(resolved)
		}
	}
	// Unknown type - use int64 as placeholder (for generic type parameters)
	return llvm.LLVMInt64Type()
}

to_const0 :: proc(ty: llvm.TypeRef) -> llvm.ValueRef {
	return cu.to_const0(ty)
}

convert_type :: proc(ctx: ^CompilerCtx, val: llvm.ValueRef, from_ty, to_ty: llvm.TypeRef) -> llvm.ValueRef {
	return cu.convert_type(ctx.builder, val, from_ty, to_ty)
}

// Convert a numeric value (i32/double) to an i1 boolean (0/1).
to_bool_i1 :: proc(ctx: ^CompilerCtx, v: ValueInfo) -> llvm.ValueRef {
	return cu.to_bool_i1(ctx.builder, cu.ValueInfo{
		val = v.val,
		ty = v.ty,
		base_type = v.base_type,
		struct_type = v.struct_type,
	})
}

zext_i1_to_i32 :: proc(ctx: ^CompilerCtx, cond_i1: llvm.ValueRef) -> llvm.ValueRef {
	return cu.zext_i1_to_i32(ctx.builder, cond_i1)
}

zext_i1_to_i64 :: proc(ctx: ^CompilerCtx, cond_i1: llvm.ValueRef) -> llvm.ValueRef {
	return cu.zext_i1_to_i64(ctx.builder, cond_i1)
}

process_imports :: proc(prog: ^ast.Program, current_file: string, alloc: mem.Allocator, verbose: bool) -> bool {
	import_nodes := [dynamic]^ast.Node{}
	other_decls := [dynamic]^ast.Node{}

	for decl in prog.declarations {
		if decl.kind == .Import_Stmt {
			append(&import_nodes, decl)
		} else {
			append(&other_decls, decl)
		}
	}

	imported_decls := [dynamic]^ast.Node{}

	for import_node in import_nodes {
		path := import_node.import_path
		if imports.is_visited(path) {
			continue
		}
		imports.mark_visited(path)

		module_path, ok := imports.resolve_module(path, current_file)
		if !ok {
			for err in imports.get_errors() {
				common.print_error(err, 0, 0)
			}
			return false
		}

		if verbose {
			common.colorf(.Yellow, "    Importing: %s\n", path)
		}

		module_source, read_err := os.read_entire_file_from_path(module_path, alloc)
		if read_err != nil {
			common.print_error(fmt.tprintf("Cannot read module: %s", path), 0, 0)
			return false
		}
		defer delete(module_source)

		l := lexer.init(string(module_source))
		tokens := lexer.scan(&l)
		module_prog := parser.parse(string(module_source), alloc)
		lexer.destroy_tokens(&tokens)

		if parser.has_errors() {
			parser.print_errors()
			return false
		}

		if !process_imports(module_prog, module_path, alloc, verbose) {
			return false
		}

		for decl in module_prog.declarations {
			append(&imported_decls, decl)
		}
	}

	all_decls := imported_decls
	for decl in import_nodes {
		append(&all_decls, decl)
	}
	for decl in other_decls {
		append(&all_decls, decl)
	}

	prog.declarations = all_decls[:]
	return true
}

compile_llvm :: proc(acorn_file: string, output_file: string, allocator: mem.Allocator = {}, verbose: bool = false, output_type: common.Output_Type = .Executable) -> bool {
	alloc := allocator
	if alloc.data == nil {
		alloc = context.allocator
	}
	source, err := os.read_entire_file_from_path(acorn_file, alloc)
	if err != nil {
		common.print_error(fmt.tprintf("Could not read file: %s", acorn_file), 0, 0)
		return false
	}
	defer delete(source)

	if verbose {
		common.colorf(.Yellow, "  Lexing...\n")
	}

	if verbose {
		common.colorf(.Yellow, "  Parsing...\n")
	}
	prog := parser.parse(string(source), allocator)

	if parser.has_errors() {
		parser.print_errors()
		return false
	}

	if verbose {
		common.colorf(.Yellow, "  Processing imports...\n")
	}
	imports.init_imports(verbose)
	if !process_imports(prog, acorn_file, alloc, verbose) {
		return false
	}

	if verbose {
		common.colorf(.Yellow, "  Type checking...\n")
	}
	if !typecheck.check_program(prog) {
		typecheck.print_errors()
		return false
	}

	if verbose {
		common.colorf(.Yellow, "  Generating LLVM IR...\n")
	}

	module := llvm.LLVMModuleCreateWithName("acorn_module")
	builder := llvm.LLVMCreateBuilder()
	ctx := llvm.LLVMGetGlobalContext()

	struct_types = make(map[string]llvm.TypeRef)
	struct_fields = make(map[string][]string)
	enum_variants = make(map[string]map[string]int)
	global_consts = make(map[string]llvm.ValueRef)
	fn_types = make(map[string]Fn_Info)
	generic_type_map = make(map[string]string)

	defer {
		llvm.LLVMDisposeBuilder(builder)
		llvm.LLVMDisposeModule(module)
		delete(struct_types)
		for key in struct_fields {
			delete(struct_fields[key])
		}
		delete(struct_fields)
		for key in enum_variants {
			delete(enum_variants[key])
		}
		delete(enum_variants)
		delete(global_consts)
		for key in fn_types {
			delete(fn_types[key].param_types)
		}
		delete(fn_types)
		delete(generic_type_map)
	}

	for decl in prog.declarations {
		if decl.kind == .Struct_Decl {
			generate_llvm_struct(module, decl)
		}
		if decl.kind == .Import_Stmt {
			continue
		}
		if decl.kind == .Enum_Decl {
			generate_llvm_enum(module, decl)
		}
		if decl.kind == .Const_Decl {
			generate_llvm_const(module, decl)
		}
		if decl.kind == .Var_Decl {
			generate_llvm_global(module, decl)
		}
		if decl.kind == .Assign_Stmt {
			generate_llvm_global_assign(module, decl)
		}
	}

	for decl in prog.declarations {
		if decl.kind == .Fn_Decl {
			generate_llvm_fn(module, builder, decl)
		}
	}

	if verbose {
		common.colorf(.Yellow, "  Verifying module...\n")
	}
	if !verify_module(module) {
		common.print_error("Module verification failed", 0, 0)
		return false
	}

	ir_cstr := llvm.LLVMPrintModuleToString(module)
	ir := strings.clone(string(ir_cstr))
	llvm.LLVMDisposeMessage(ir_cstr)
	defer delete(ir)

	if output_type == .Assembly {
		if verbose {
			common.colorf(.Yellow, "  Writing assembly to: %s\n", output_file)
		}
		err2 := os.write_entire_file(output_file, transmute([]u8)ir)
		if err2 != nil {
			common.print_error(fmt.tprintf("Could not write file: %s", output_file), 0, 0)
			return false
		}
		return true
	}

	llvm_file := "acorn_generated.ll"

	if verbose {
		common.colorf(.Yellow, "  Writing IR to: %s\n", llvm_file)
	}

	err2 := os.write_entire_file(llvm_file, transmute([]u8)ir)
	if err2 != nil {
		common.print_error(fmt.tprintf("Could not write file: %s", llvm_file), 0, 0)
		return false
	}

	obj_file := "acorn_generated.o"

	if output_type == .Object {
		if verbose {
			common.colorf(.Yellow, "  Compiling to object file: %s\n", output_file)
		}
		llc_cmd := fmt.tprintf("llc --filetype=obj -o %s %s", output_file, llvm_file)
		if run_command(llc_cmd) != 0 {
			common.print_error("LLVM compilation failed", 0, 0)
			return false
		}
		os.remove(llvm_file)
		return true
	}

	if verbose {
		common.colorf(.Yellow, "  Linking...\n")
	}

	llc_cmd := fmt.tprintf("llc --filetype=obj -o %s %s", obj_file, llvm_file)
	if run_command(llc_cmd) != 0 {
		common.print_error("LLVM compilation failed", 0, 0)
		return false
	}

	link_cmd := fmt.tprintf("clang %s -o %s -no-pie", obj_file, output_file)
	if run_command(link_cmd) != 0 {
		common.print_error("Linking failed", 0, 0)
		return false
	}

	os.remove(llvm_file)
	os.remove(obj_file)

	return true
}

generate_llvm_struct :: proc(module: llvm.ModuleRef, node: ^ast.Node) {
	struct_name := node.name
	name_c := strings.clone_to_cstring(struct_name)
	defer delete(name_c)

	struct_ty := llvm.LLVMStructCreateNamed(llvm.LLVMGetGlobalContext(), name_c)
	struct_types[struct_name] = struct_ty

	if node.fields != nil && len(node.fields) > 0 {
		elem_types := make([]llvm.TypeRef, len(node.fields))
		defer delete(elem_types)
		field_names := make([]string, len(node.fields))
		for i := 0; i < len(node.fields); i += 1 {
			field_type_name := node.fields[i].type.name
			elem_types[i] = get_llvm_type(field_type_name)
			field_names[i] = strings.clone(node.fields[i].name)
		}
		llvm.LLVMStructSetBody(struct_ty, raw_data(elem_types), uint(len(elem_types)), 0)
		struct_fields[struct_name] = field_names
	}
}

generate_llvm_enum :: proc(module: llvm.ModuleRef, node: ^ast.Node) {
	enum_name := node.name
	variant_map := make(map[string]int)
	for i in 0..<len(node.enum_variants) {
		variant_map[node.enum_variants[i].name] = node.enum_variants[i].value
	}
	enum_variants[enum_name] = variant_map
}

generate_llvm_const :: proc(module: llvm.ModuleRef, node: ^ast.Node) {
	name := node.name
	name_c := strings.clone_to_cstring(name)
	defer delete(name_c)

	llvm_ty: llvm.TypeRef
	if node.return_type.name != "" {
		llvm_ty = get_llvm_type(node.return_type.name)
	} else if node.value != nil {
		llvm_ty = get_llvm_type_for_value(node.value)
	} else {
		llvm_ty = llvm.LLVMInt64Type()
	}

	global_var := llvm.LLVMAddGlobal(module, llvm_ty, name_c)
	llvm.LLVMSetGlobalConstant(global_var, true)

	if node.value != nil {
		const_val := const_expr_value(module, llvm_ty, node.value)
		if const_val != nil {
			llvm.LLVMSetInitializer(global_var, const_val)
		}
	}

	global_consts[name] = global_var
}

get_llvm_type_for_value :: proc(node: ^ast.Node) -> llvm.TypeRef {
	if node == nil do return llvm.LLVMInt64Type()
	#partial switch node.kind {
	case .Int_Literal:
		return llvm.LLVMInt64Type()
	case .Float_Literal:
		return llvm.LLVMDoubleType()
	case .Bool_Literal:
		return llvm.LLVMInt32Type()
	case .String_Literal:
		return llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
	}
	return llvm.LLVMInt64Type()
}

generate_llvm_global :: proc(module: llvm.ModuleRef, node: ^ast.Node) {
	name := node.name
	name_c := strings.clone_to_cstring(name)
	defer delete(name_c)

	llvm_ty: llvm.TypeRef
	if node.return_type.name != "" {
		llvm_ty = get_llvm_type(node.return_type.name)
	} else {
		llvm_ty = llvm.LLVMInt64Type()
	}

	global_var := llvm.LLVMAddGlobal(module, llvm_ty, name_c)
	llvm.LLVMSetGlobalConstant(global_var, false)

	if node.value != nil {
		const_val := const_expr_value(module, llvm_ty, node.value)
		if const_val != nil {
			llvm.LLVMSetInitializer(global_var, const_val)
		}
	}

	global_consts[name] = global_var
}

generate_llvm_global_assign :: proc(module: llvm.ModuleRef, node: ^ast.Node) {
	name := node.target
	name_c := strings.clone_to_cstring(name)
	defer delete(name_c)

	if _, exists := global_consts[name]; exists {
		return
	}

	llvm_ty := llvm.LLVMInt64Type()
	if node.value != nil {
		#partial switch node.value.kind {
		case .Float_Literal:
			llvm_ty = llvm.LLVMDoubleType()
		case .Bool_Literal:
			llvm_ty = llvm.LLVMInt32Type()
		}
	}

	global_var := llvm.LLVMAddGlobal(module, llvm_ty, name_c)
	llvm.LLVMSetGlobalConstant(global_var, false)

	if node.value != nil {
		const_val := const_expr_value(module, llvm_ty, node.value)
		if const_val != nil {
			llvm.LLVMSetInitializer(global_var, const_val)
		}
	}

	global_consts[name] = global_var
}

const_expr_value :: proc(module: llvm.ModuleRef, expected_ty: llvm.TypeRef, node: ^ast.Node) -> llvm.ValueRef {
	if node == nil do return nil

	#partial switch node.kind {
	case .Int_Literal:
		return llvm.LLVMConstInt(llvm.LLVMInt64Type(), u64(node.int_value), 0)
	case .Float_Literal:
		return llvm.LLVMConstReal(llvm.LLVMDoubleType(), node.float_value)
	case .Bool_Literal:
		b := i8(node.bool_value ? 1 : 0)
		return llvm.LLVMConstInt(llvm.LLVMInt32Type(), u64(b), 0)
	case .String_Literal:
		str_c := strings.clone_to_cstring(node.string_value)
		defer delete(str_c)
		return llvm.LLVMAddGlobal(module, llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0), str_c)
	case .Ident:
		if gv, ok := global_consts[node.name]; ok {
			return llvm.LLVMGetInitializer(gv)
		}
	}
	return nil
}

generate_llvm_fn :: proc(module: llvm.ModuleRef, builder: llvm.BuilderRef, node: ^ast.Node) {
	fn_name := node.name

	// Handle forward declarations (generic functions without body)
	if node.body == nil {
		ret_type: llvm.TypeRef
		ret_name := node.return_type.name
		if ret_name == "" || ret_name == "int" || ret_name == "i32" {
			ret_type = llvm.LLVMInt32Type()
		} else if ret_name == "f64" || ret_name == "float" {
			ret_type = llvm.LLVMDoubleType()
		} else if ret_name == "string" || ret_name == "str" {
			ret_type = llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
		} else if ret_name == "bool" {
			ret_type = llvm.LLVMInt1Type()
		} else if st, ok := struct_types[ret_name]; ok {
			ret_type = st
		} else {
			ret_type = llvm.LLVMInt32Type()
		}

		param_count := uint(0)
		if node.params != nil {
			param_count = uint(len(node.params))
		}

		param_types := make([]llvm.TypeRef, param_count)
		defer delete(param_types)
		for i := 0; i < int(param_count); i += 1 {
			param_ty_name := node.params[i].type.name
			if param_ty_name == "f64" || param_ty_name == "float" {
				param_types[i] = llvm.LLVMDoubleType()
			} else if param_ty_name == "string" || param_ty_name == "str" {
				param_types[i] = llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
			} else if param_ty_name == "bool" {
				param_types[i] = llvm.LLVMInt1Type()
			} else if param_ty_name == "int" || param_ty_name == "i32" {
				param_types[i] = llvm.LLVMInt64Type()
			} else if param_ty_name == "f32" {
				param_types[i] = llvm.LLVMDoubleType()
			} else if st, ok := struct_types[param_ty_name]; ok {
				param_types[i] = st
			} else {
				param_types[i] = llvm.LLVMInt64Type()
			}
		}

		fn_ty := llvm.LLVMFunctionType(ret_type, raw_data(param_types), param_count, 0)
		fn_name_c := strings.clone_to_cstring(fn_name)
		defer delete(fn_name_c)
		llvm.LLVMAddFunction(module, fn_name_c, fn_ty)

		param_types_copy := make([]llvm.TypeRef, int(param_count))
		copy(param_types_copy, param_types)
		fn_types[fn_name] = Fn_Info{
			ret_type = ret_type,
			param_types = param_types_copy,
			generic_params = node.generic_params,
		}
		return
	}

	ret_type: llvm.TypeRef
	ret_name := node.return_type.name

	// Handle generic type parameters - use i32 as default
	is_generic_return := false
	if len(node.generic_params) > 0 && ret_name != "" {
		for gp in node.generic_params {
			if ret_name == gp {
				is_generic_return = true
				break
			}
		}
	}

	// Use i32 for int return types (matches literal type)
	if ret_name == "" || is_generic_return {
		ret_type = llvm.LLVMInt32Type()
	} else if ret_name == "int" || ret_name == "i32" {
		ret_type = llvm.LLVMInt32Type()
	} else if ret_name == "f64" || ret_name == "float" {
		ret_type = llvm.LLVMDoubleType()
	} else if ret_name == "f32" {
		ret_type = llvm.LLVMDoubleType()
	} else if ret_name == "string" || ret_name == "str" {
		ret_type = llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
	} else if ret_name == "bool" {
		ret_type = llvm.LLVMInt1Type()
	} else if ret_name == "i32" {
		ret_type = llvm.LLVMInt32Type()
	} else if ret_name == "i8" || ret_name == "byte" {
		ret_type = llvm.LLVMInt8Type()
	} else if st, ok := struct_types[ret_name]; ok {
		ret_type = st
	} else {
		ret_type = llvm.LLVMInt32Type()
	}

	param_count := uint(0)
	if node.params != nil {
		param_count = uint(len(node.params))
	}

	param_types := make([]llvm.TypeRef, param_count)
	defer delete(param_types)
	for i in 0 ..< param_count {
		param_ty_name := node.params[i].type.name

		// Handle generic type parameters - use i32 as default
		is_generic_param := false
		if len(node.generic_params) > 0 {
			for gp in node.generic_params {
				if param_ty_name == gp {
					is_generic_param = true
					break
				}
			}
		}

		if is_generic_param {
			param_types[i] = llvm.LLVMInt32Type()
		} else if param_ty_name == "f64" || param_ty_name == "float" {
			param_types[i] = llvm.LLVMDoubleType()
		} else if param_ty_name == "f32" {
			param_types[i] = llvm.LLVMDoubleType()
		} else if param_ty_name == "string" || param_ty_name == "str" {
			param_types[i] = llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
		} else if param_ty_name == "bool" {
			param_types[i] = llvm.LLVMInt1Type()
		} else if param_ty_name == "int" || param_ty_name == "i32" {
			param_types[i] = llvm.LLVMInt32Type()
		} else if param_ty_name == "i8" || param_ty_name == "byte" {
			param_types[i] = llvm.LLVMInt8Type()
		} else if st, ok := struct_types[param_ty_name]; ok {
			param_types[i] = st
		} else {
			param_types[i] = llvm.LLVMInt32Type()
		}
	}

	fn_type := llvm.LLVMFunctionType(ret_type, raw_data(param_types), uint(param_count), 0)
	fn_name_c := strings.clone_to_cstring(fn_name)
	fn := llvm.LLVMAddFunction(module, fn_name_c, fn_type)
	delete(fn_name_c)

	param_types_copy := make([]llvm.TypeRef, param_count)
	for i in 0..<param_count {
		param_types_copy[i] = param_types[i]
	}
	fn_types[fn_name] = Fn_Info{
		ret_type = ret_type,
		param_types = param_types_copy,
		generic_params = node.generic_params,
	}

	entry_bb := llvm.LLVMAppendBasicBlock(fn, "entry")
	llvm.LLVMPositionBuilderAtEnd(builder, entry_bb)

	ctx := CompilerCtx {
		module       = module,
		builder      = builder,
		fn           = fn,
		fn_ret_type  = ret_type,
		fn_ret_name  = ret_name,
		break_bb     = nil,
		continue_bb  = nil,
		allocator    = context.allocator,
	}
	defer {
		delete(ctx.vars)
	}

	// Bind parameters to stack slots.
	for i in 0 ..< param_count {
		param := node.params[i]
		param_name := param.name
		param_ty := param_types[i]

		param_name_c := strings.clone_to_cstring(param_name)
		alloca := llvm.LLVMBuildAlloca(builder, param_ty, param_name_c)
		delete(param_name_c)
		param_val := llvm.LLVMGetParam(fn, uint(i))
		llvm.LLVMBuildStore(builder, param_val, alloca)

		add_var(&ctx, param_name, alloca, param_ty, "", node.params[i].type.name)
	}

	terminated := false
	if node.body != nil && node.body.statements != nil {
		for stmt in node.body.statements {
			terminated = generate_llvm_stmt(&ctx, stmt)
			if terminated {
				break
			}
		}
	}

	if !terminated {
		// For void functions (no return type), use ret void
		if node.return_type.name == "" {
			// Void function - use ret void
			llvm.LLVMBuildRetVoid(ctx.builder)
		} else {
			ret_kind := llvm.LLVMGetTypeKind(ctx.fn_ret_type)
			if ret_kind == .StructTypeKind {
				// For struct returns, return a zero pointer (caller will handle properly)
				zero := llvm.LLVMConstInt(llvm.LLVMInt64Type(), 0, 0)
				zero_ptr := llvm.LLVMBuildIntToPtr(ctx.builder, zero, ctx.fn_ret_type, "zero_struct")
				llvm.LLVMBuildRet(ctx.builder, zero_ptr)
			} else if ctx.fn_ret_type == llvm.LLVMDoubleType() {
				llvm.LLVMBuildRet(ctx.builder, llvm.LLVMConstReal(llvm.LLVMDoubleType(), 0.0))
			} else if ctx.fn_ret_type == llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0) {
				zero := llvm.LLVMConstInt(llvm.LLVMInt64Type(), 0, 0)
				null_ptr := llvm.LLVMBuildIntToPtr(ctx.builder, zero, ctx.fn_ret_type, "null_ptr")
				llvm.LLVMBuildRet(ctx.builder, null_ptr)
			} else if ctx.fn_ret_type == llvm.LLVMInt1Type() {
				llvm.LLVMBuildRet(ctx.builder, llvm.LLVMConstInt(llvm.LLVMInt1Type(), 0, 0))
			} else {
				llvm.LLVMBuildRet(ctx.builder, llvm.LLVMConstInt(ctx.fn_ret_type, 0, 0))
			}
		}
	}
}

generate_llvm_stmt :: proc(ctx: ^CompilerCtx, node: ^ast.Node) -> bool {
	if node == nil {
		return false
	}

	if node.kind == .Return_Stmt {
		if node.value != nil {
			v := generate_llvm_expr(ctx, node.value)
			
			// For struct returns, we need to load the value if it's still a pointer
			ret_kind := llvm.LLVMGetTypeKind(ctx.fn_ret_type)
			return_val := v.val
			if ret_kind == .StructTypeKind && v.struct_type != "" {
				// v.val is an alloca, we need to load the actual struct value
				loaded := llvm.LLVMBuildLoad2(ctx.builder, ctx.fn_ret_type, v.val, "ret_val")
				return_val = loaded
			}
			
			if v.ty == ctx.fn_ret_type {
				llvm.LLVMBuildRet(ctx.builder, return_val)
			} else {
				ret_val := convert_type(ctx, return_val, v.ty, ctx.fn_ret_type)
				llvm.LLVMBuildRet(ctx.builder, ret_val)
			}
		} else {
			ret_kind := llvm.LLVMGetTypeKind(ctx.fn_ret_type)
			if ret_kind == .StructTypeKind {
				zero_ptr := llvm.LLVMConstInt(llvm.LLVMInt64Type(), 0, 0)
				zero := llvm.LLVMBuildIntToPtr(ctx.builder, zero_ptr, ctx.fn_ret_type, "zero_struct")
				llvm.LLVMBuildRet(ctx.builder, zero)
			} else if ctx.fn_ret_type == llvm.LLVMDoubleType() {
				llvm.LLVMBuildRet(ctx.builder, llvm.LLVMConstReal(llvm.LLVMDoubleType(), 0.0))
			} else if ctx.fn_ret_type == llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0) {
				zero := llvm.LLVMConstInt(llvm.LLVMInt64Type(), 0, 0)
				null_ptr := llvm.LLVMBuildIntToPtr(ctx.builder, zero, ctx.fn_ret_type, "null_ptr")
				llvm.LLVMBuildRet(ctx.builder, null_ptr)
			} else if ctx.fn_ret_type == llvm.LLVMInt1Type() {
				llvm.LLVMBuildRet(ctx.builder, llvm.LLVMConstInt(llvm.LLVMInt1Type(), 0, 0))
			} else {
				llvm.LLVMBuildRet(ctx.builder, llvm.LLVMConstInt(ctx.fn_ret_type, 0, 0))
			}
		}
		return true
	}

	if node.kind == .Expr_Stmt && node.value != nil {
		generate_llvm_expr(ctx, node.value)
		return false
	}

	if node.kind == .Var_Decl {
		is_array_type := node.return_type.is_array
		pointer_level := node.return_type.pointer_level
		base_type := node.return_type.base_type
		
		elem_ty := get_llvm_type(base_type)
		is_struct := false
		is_array := false
		if _, ok := struct_types[base_type]; ok {
			is_struct = true
		}
		if node.return_type.is_array {
			is_array = true
		}

		if node.value != nil {
			v := generate_llvm_expr(ctx, node.value)
			kind := llvm.LLVMGetTypeKind(v.ty)

			if pointer_level > 0 || kind == .PointerTypeKind {
				ptr_storage_ty := llvm.LLVMPointerType(elem_ty, 0)
				for i in 1..<pointer_level {
					ptr_storage_ty = llvm.LLVMPointerType(ptr_storage_ty, 0)
				}
				var_name_c := strings.clone_to_cstring(node.name)
				alloca := llvm.LLVMBuildAlloca(
					ctx.builder,
					ptr_storage_ty,
					var_name_c,
				)
				delete(var_name_c)
				llvm.LLVMBuildStore(ctx.builder, v.val, alloca)
				add_var(ctx, node.name, alloca, ptr_storage_ty, base_type, "")
			} else if is_struct {
				var_name_c := strings.clone_to_cstring(node.name)
				alloca := llvm.LLVMBuildAlloca(
					ctx.builder,
					elem_ty,
					var_name_c,
				)
				delete(var_name_c)
				loaded := llvm.LLVMBuildLoad2(ctx.builder, elem_ty, v.val, "struct_copy")
				llvm.LLVMBuildStore(ctx.builder, loaded, alloca)
				add_var(ctx, node.name, alloca, elem_ty, base_type, "")
			} else if is_array {
				var_name_c := strings.clone_to_cstring(node.name)
				alloca := llvm.LLVMBuildAlloca(
					ctx.builder,
					elem_ty,
					var_name_c,
				)
				delete(var_name_c)
				loaded := llvm.LLVMBuildLoad2(ctx.builder, elem_ty, v.val, "array_copy")
				llvm.LLVMBuildStore(ctx.builder, loaded, alloca)
				add_var(ctx, node.name, alloca, elem_ty, "", base_type)
			} else {
				var_name_c := strings.clone_to_cstring(node.name)
				alloca := llvm.LLVMBuildAlloca(
					ctx.builder,
					elem_ty,
					var_name_c,
				)
				delete(var_name_c)
				if v.ty != elem_ty {
					v.val = convert_type(ctx, v.val, v.ty, elem_ty)
				}
				llvm.LLVMBuildStore(ctx.builder, v.val, alloca)
				add_var(ctx, node.name, alloca, elem_ty, "", "")
			}
		} else {
			var_name_c := strings.clone_to_cstring(node.name)
			alloca := llvm.LLVMBuildAlloca(ctx.builder, elem_ty, var_name_c)
			delete(var_name_c)
			llvm.LLVMBuildStore(ctx.builder, to_const0(elem_ty), alloca)
			if is_struct || base_type != "" {
				add_var(ctx, node.name, alloca, elem_ty, "", base_type)
			} else if is_array {
				add_var(ctx, node.name, alloca, elem_ty, "", base_type)
			} else {
				add_var(ctx, node.name, alloca, elem_ty, "", "")
			}
		}
		return false
	}

	if node.kind == .Const_Decl {
		name := node.name
		name_c := strings.clone_to_cstring(name)
		defer delete(name_c)

		llvm_ty: llvm.TypeRef
		if node.return_type.name != "" {
			llvm_ty = get_llvm_type(node.return_type.name)
		} else if node.value != nil {
			llvm_ty = get_llvm_type_for_value(node.value)
		} else {
			llvm_ty = llvm.LLVMInt32Type()
		}

		alloca := llvm.LLVMBuildAlloca(ctx.builder, llvm_ty, name_c)
		if node.value != nil {
			v := generate_llvm_expr(ctx, node.value)
			if v.ty != llvm_ty {
				v.val = convert_type(ctx, v.val, v.ty, llvm_ty)
			}
			llvm.LLVMBuildStore(ctx.builder, v.val, alloca)
		}
		add_var(ctx, name, alloca, llvm_ty, "", "")
		return false
	}

	if node.kind == .Assign_Stmt {
		vi_ptr, vi_ty, _, _, found := find_var(ctx, node.target)

		if !found {
			v := generate_llvm_expr(ctx, node.value)
			kind := llvm.LLVMGetTypeKind(v.ty)
			if kind == .PointerTypeKind {
				ptr_ty := llvm.LLVMPointerType(llvm.LLVMInt32Type(), 0)
				target_c := strings.clone_to_cstring(node.target)
				vi_ptr = llvm.LLVMBuildAlloca(
					ctx.builder,
					ptr_ty,
					target_c,
				)
				delete(target_c)
				vi_ty = ptr_ty
			} else {
			target_c := strings.clone_to_cstring(node.target)
			vi_ptr = llvm.LLVMBuildAlloca(
				ctx.builder,
				llvm.LLVMInt32Type(),
				target_c,
			)
			delete(target_c)
			vi_ty = llvm.LLVMInt32Type()
		}
			add_var(ctx, node.target, vi_ptr, vi_ty, "", "")

			if v.ty != vi_ty {
				if vi_ty == llvm.LLVMDoubleType() && v.ty == llvm.LLVMInt32Type() {
					v.val = llvm.LLVMBuildSIToFP(ctx.builder, v.val, vi_ty, "itof")
				} else if vi_ty == llvm.LLVMInt32Type() && v.ty == llvm.LLVMDoubleType() {
					v.val = llvm.LLVMBuildFPToSI(ctx.builder, v.val, vi_ty, "ftoi")
				}
			}
			llvm.LLVMBuildStore(ctx.builder, v.val, vi_ptr)
		} else {
			v := generate_llvm_expr(ctx, node.value)
			if v.ty != vi_ty {
				if vi_ty == llvm.LLVMDoubleType() && v.ty == llvm.LLVMInt32Type() {
					v.val = llvm.LLVMBuildSIToFP(ctx.builder, v.val, vi_ty, "itof")
				} else if vi_ty == llvm.LLVMInt32Type() && v.ty == llvm.LLVMDoubleType() {
					v.val = llvm.LLVMBuildFPToSI(ctx.builder, v.val, vi_ty, "ftoi")
				}
			}
			llvm.LLVMBuildStore(ctx.builder, v.val, vi_ptr)
		}
		return false
	}

	if node.kind == .Block_Stmt && node.statements != nil {
		terminated := false
		for stmt in node.statements {
			terminated = generate_llvm_stmt(ctx, stmt)
			if terminated {
				break
			}
		}
		return terminated
	}

	if node.kind == .If_Stmt {
		cond := generate_llvm_expr(ctx, node.condition)
		cond_i1 := to_bool_i1(ctx, cond)

		then_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "then")
		end_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "if_end")
		else_bb := end_bb
		if node.else_branch != nil {
			else_bb = llvm.LLVMAppendBasicBlock(ctx.fn, "else")
		}

		llvm.LLVMBuildCondBr(ctx.builder, cond_i1, then_bb, else_bb)

		llvm.LLVMPositionBuilderAtEnd(ctx.builder, then_bb)
		then_term := generate_llvm_stmt(ctx, node.body)
		if !then_term {
			llvm.LLVMBuildBr(ctx.builder, end_bb)
		}

		if node.else_branch != nil {
			llvm.LLVMPositionBuilderAtEnd(ctx.builder, else_bb)
			else_term := generate_llvm_stmt(ctx, node.else_branch)
			if !else_term {
				llvm.LLVMBuildBr(ctx.builder, end_bb)
			}
		}

		llvm.LLVMPositionBuilderAtEnd(ctx.builder, end_bb)
		return false
	}

	if node.kind == .For_Stmt {
		cond_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "for_cond")
		body_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "for_body")
		update_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "for_update")
		end_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "for_end")

		// init
		if node.init != nil {
			if node.init.kind == .Assign_Stmt || node.init.kind == .Var_Decl {
				_ = generate_llvm_stmt(ctx, node.init)
			} else {
				generate_llvm_expr(ctx, node.init)
			}
		}

		llvm.LLVMBuildBr(ctx.builder, cond_bb)

		// condition
		llvm.LLVMPositionBuilderAtEnd(ctx.builder, cond_bb)
		cond_i1: llvm.ValueRef
		if node.condition != nil {
			cond := generate_llvm_expr(ctx, node.condition)
			cond_i1 = to_bool_i1(ctx, cond)
		} else {
			cond_i1 = llvm.LLVMConstInt(llvm.LLVMInt1Type(), 1, 0)
		}
		llvm.LLVMBuildCondBr(ctx.builder, cond_i1, body_bb, end_bb)

		// body
		llvm.LLVMPositionBuilderAtEnd(ctx.builder, body_bb)
		body_term := generate_llvm_stmt(ctx, node.body)
		if !body_term {
			llvm.LLVMBuildBr(ctx.builder, update_bb)
		}

		// update
		llvm.LLVMPositionBuilderAtEnd(ctx.builder, update_bb)
		if node.update != nil {
			if node.update.kind == .Assign_Stmt || node.update.kind == .Var_Decl {
				_ = generate_llvm_stmt(ctx, node.update)
			} else {
				generate_llvm_expr(ctx, node.update)
			}
		}
		llvm.LLVMBuildBr(ctx.builder, cond_bb)

		llvm.LLVMPositionBuilderAtEnd(ctx.builder, end_bb)
		return false
	}

	if node.kind == .For_In_Stmt {
		start_val := generate_llvm_expr(ctx, node.range_start)
		end_val := generate_llvm_expr(ctx, node.range_end)

		step_val: ValueInfo
		if node.range_step != nil {
			step_val = generate_llvm_expr(ctx, node.range_step)
		} else {
			step_val = ValueInfo {
				val = llvm.LLVMConstInt(llvm.LLVMInt32Type(), 1, 0),
				ty  = llvm.LLVMInt32Type(),
			}
		}

		cond_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "for_in_cond")
		body_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "for_in_body")
		update_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "for_in_update")
		end_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "for_in_end")

		saved_break := ctx.break_bb
		saved_continue := ctx.continue_bb
		ctx.break_bb = end_bb
		ctx.continue_bb = update_bb

		for_var_c := strings.clone_to_cstring(node.for_var)
		var_ptr := llvm.LLVMBuildAlloca(
			ctx.builder,
			llvm.LLVMInt32Type(),
			for_var_c,
		)
		delete(for_var_c)
		add_var(ctx, node.for_var, var_ptr, llvm.LLVMInt32Type(), "", "")

		llvm.LLVMBuildStore(ctx.builder, start_val.val, var_ptr)
		llvm.LLVMBuildBr(ctx.builder, cond_bb)

		llvm.LLVMPositionBuilderAtEnd(ctx.builder, cond_bb)
		for_var_c = strings.clone_to_cstring(node.for_var)
		current_val := llvm.LLVMBuildLoad2(
			ctx.builder,
			llvm.LLVMInt32Type(),
			var_ptr,
			for_var_c,
		)
		delete(for_var_c)

		cmp_op := LLVMIntSLT
		if node.range_inclusive {
			cmp_op = LLVMIntSLE
		}
		cmp_result := llvm.LLVMBuildICmp(ctx.builder, cmp_op, current_val, end_val.val, "loop_cmp")
		llvm.LLVMBuildCondBr(ctx.builder, cmp_result, body_bb, end_bb)

		llvm.LLVMPositionBuilderAtEnd(ctx.builder, body_bb)
		body_term := generate_llvm_stmt(ctx, node.body)
		if !body_term {
			llvm.LLVMBuildBr(ctx.builder, update_bb)
		}

		llvm.LLVMPositionBuilderAtEnd(ctx.builder, update_bb)
		for_var_c = strings.clone_to_cstring(node.for_var)
		current_val2 := llvm.LLVMBuildLoad2(
			ctx.builder,
			llvm.LLVMInt32Type(),
			var_ptr,
			for_var_c,
		)
		delete(for_var_c)
		new_val := llvm.LLVMBuildAdd(ctx.builder, current_val2, step_val.val, "loop_inc")
		llvm.LLVMBuildStore(ctx.builder, new_val, var_ptr)
		llvm.LLVMBuildBr(ctx.builder, cond_bb)

		llvm.LLVMPositionBuilderAtEnd(ctx.builder, end_bb)

		ctx.break_bb = saved_break
		ctx.continue_bb = saved_continue

		return false
	}

	if node.kind == .For_Condition_Stmt {
		cond_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "while_cond")
		body_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "while_body")
		end_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "while_end")

		saved_break := ctx.break_bb
		saved_continue := ctx.continue_bb
		ctx.break_bb = end_bb
		ctx.continue_bb = cond_bb

		llvm.LLVMBuildBr(ctx.builder, cond_bb)

		llvm.LLVMPositionBuilderAtEnd(ctx.builder, cond_bb)
		cond_val := generate_llvm_expr(ctx, node.condition)
		cond_i1 := to_bool_i1(ctx, cond_val)
		llvm.LLVMBuildCondBr(ctx.builder, cond_i1, body_bb, end_bb)

		llvm.LLVMPositionBuilderAtEnd(ctx.builder, body_bb)
		body_term := generate_llvm_stmt(ctx, node.body)
		if !body_term {
			llvm.LLVMBuildBr(ctx.builder, cond_bb)
		}

		llvm.LLVMPositionBuilderAtEnd(ctx.builder, end_bb)

		ctx.break_bb = saved_break
		ctx.continue_bb = saved_continue

		return false
	}

	if node.kind == .Match_Stmt {
		match_val := generate_llvm_expr(ctx, node.match_value)
		end_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "match_end")

		if len(node.match_patterns) > 0 {
			for i := 0; i < len(node.match_patterns); i += 1 {
				pattern_val := generate_llvm_expr(ctx, node.match_patterns[i])

				cmp_ty := llvm.LLVMInt64Type()
				match_int := match_val.val
				pattern_int := pattern_val.val

				if match_val.ty != llvm.LLVMInt64Type() {
					match_int = llvm.LLVMBuildSExt(ctx.builder, match_val.val, cmp_ty, "match_ext")
				}
				if pattern_val.ty != llvm.LLVMInt64Type() {
					pattern_int = llvm.LLVMBuildSExt(ctx.builder, pattern_val.val, cmp_ty, "pattern_ext")
				}

				cmp := llvm.LLVMBuildICmp(ctx.builder, LLVMIntEQ, match_int, pattern_int, "match_cmp")
				next_bb: llvm.BasicBlockRef
				if i + 1 < len(node.match_patterns) {
					next_bb = llvm.LLVMAppendBasicBlock(ctx.fn, "match_case_next")
				} else {
					next_bb = end_bb
				}
				body_bb := llvm.LLVMAppendBasicBlock(ctx.fn, "match_case_body")
				llvm.LLVMBuildCondBr(ctx.builder, cmp, body_bb, next_bb)

				llvm.LLVMPositionBuilderAtEnd(ctx.builder, body_bb)
				if i < len(node.cases) {
					generate_llvm_stmt(ctx, node.cases[i])
				}
				llvm.LLVMBuildBr(ctx.builder, end_bb)

				llvm.LLVMPositionBuilderAtEnd(ctx.builder, next_bb)
			}
		}

		llvm.LLVMPositionBuilderAtEnd(ctx.builder, end_bb)
		return false
	}

	if node.kind == .Break_Stmt {
		if ctx.break_bb != nil {
			llvm.LLVMBuildBr(ctx.builder, ctx.break_bb)
		}
		return true
	}

	if node.kind == .Continue_Stmt {
		if ctx.continue_bb != nil {
			llvm.LLVMBuildBr(ctx.builder, ctx.continue_bb)
		}
		return true
	}

	return false
}

generate_llvm_read_line :: proc(ctx: ^CompilerCtx) -> ValueInfo {
	char_ptr_ty := llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
	arr_size := 4096
	arr_ptr := llvm.LLVMBuildArrayAlloca(ctx.builder, llvm.LLVMInt8Type(), llvm.LLVMConstInt(llvm.LLVMInt64Type(), u64(arr_size), 0), "input_buffer")
	
	scanf_name := strings.clone_to_cstring("scanf")
	defer delete(scanf_name)
	scanf_fn := llvm.LLVMGetNamedFunction(ctx.module, scanf_name)
	if scanf_fn == nil {
		i8ptr := llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
		ptr_tys := []llvm.TypeRef{i8ptr, i8ptr}
		scanf_ty := llvm.LLVMFunctionType(llvm.LLVMInt32Type(), raw_data(ptr_tys), 2, 1)
		scanf_fn = llvm.LLVMAddFunction(ctx.module, scanf_name, scanf_ty)
	}
	
	fmt_str := llvm.LLVMBuildGlobalStringPtr(ctx.builder, " %4095[^\n]", "input_fmt")
	args := []llvm.ValueRef{fmt_str, arr_ptr}
	call := llvm.LLVMBuildCall2(
		ctx.builder,
		llvm.LLVMFunctionType(llvm.LLVMInt32Type(), raw_data([]llvm.TypeRef{char_ptr_ty, char_ptr_ty}), 2, 1),
		scanf_fn,
		raw_data(args),
		2,
		"readtmp",
	)

	return ValueInfo{val = arr_ptr, ty = char_ptr_ty}
}

generate_llvm_input :: proc(ctx: ^CompilerCtx) -> ValueInfo {
	char_ptr_ty := llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
	arr_size := 4096
	arr_ptr := llvm.LLVMBuildArrayAlloca(ctx.builder, llvm.LLVMInt8Type(), llvm.LLVMConstInt(llvm.LLVMInt64Type(), u64(arr_size), 0), "input_buffer")
	
	scanf_name := strings.clone_to_cstring("scanf")
	defer delete(scanf_name)
	scanf_fn := llvm.LLVMGetNamedFunction(ctx.module, scanf_name)
	if scanf_fn == nil {
		i8ptr := llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
		fmt_ty := llvm.LLVMBuildGlobalStringPtr(ctx.builder, "%4095[^\n]", "fmt_str")
		ptr_tys := []llvm.TypeRef{i8ptr, i8ptr}
		scanf_ty := llvm.LLVMFunctionType(llvm.LLVMInt32Type(), raw_data(ptr_tys), 2, 1)
		scanf_fn = llvm.LLVMAddFunction(ctx.module, scanf_name, scanf_ty)
	}
	
	fmt_str := llvm.LLVMBuildGlobalStringPtr(ctx.builder, " %4095[^\n]", "input_fmt")
	args := []llvm.ValueRef{fmt_str, arr_ptr}
	call := llvm.LLVMBuildCall2(
		ctx.builder,
		llvm.LLVMFunctionType(llvm.LLVMInt32Type(), raw_data([]llvm.TypeRef{char_ptr_ty, char_ptr_ty}), 2, 1),
		scanf_fn,
		raw_data(args),
		2,
		"inputtmp",
	)

	return ValueInfo{val = arr_ptr, ty = char_ptr_ty}
}

generate_llvm_printf :: proc(ctx: ^CompilerCtx, fmt_str: string, args: []^ast.Node) -> llvm.ValueRef {
	printf_name := strings.clone_to_cstring("printf")
	defer delete(printf_name)
	printf_fn := llvm.LLVMGetNamedFunction(ctx.module, printf_name)
	if printf_fn == nil {
		i8ptr := llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
		ptr_tys := []llvm.TypeRef{i8ptr}
		printf_ty := llvm.LLVMFunctionType(llvm.LLVMInt32Type(), raw_data(ptr_tys), 1, 1)
		printf_fn = llvm.LLVMAddFunction(ctx.module, printf_name, printf_ty)
	}

	result := [dynamic]u8{}
	arg_idx := 0

	i := 0
	for i < len(fmt_str) {
		ch := fmt_str[i]
		
		if ch == '%' {
			if i + 1 < len(fmt_str) && fmt_str[i + 1] == '%' {
				append(&result, '%')
				append(&result, '%')
				i += 2
				continue
			}
			
			spec_end := i
			for spec_end < len(fmt_str) {
				c := fmt_str[spec_end]
				if c == 'd' || c == 'i' || c == 'u' || c == 'f' || c == 'F' || 
				   c == 'e' || c == 'E' || c == 'g' || c == 'G' || c == 's' {
					if arg_idx < len(args) {
						for k := i; k <= spec_end; k += 1 {
							append(&result, fmt_str[k])
						}
						arg_idx += 1
					}
					i = spec_end + 1
					break
				}
				spec_end += 1
				if spec_end >= len(fmt_str) {
					append(&result, '%')
					i += 1
					break
				}
			}
			continue
		}
		
		if ch == '\\' && i + 1 < len(fmt_str) {
			next := fmt_str[i + 1]
			switch next {
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
			case:
				append(&result, ch)
				append(&result, next)
			}
			i += 2
			continue
		}
		
		append(&result, ch)
		i += 1
	}

	fmt_c := strings.clone_to_cstring(string(result[:]))
	defer delete(fmt_c)
	fmt_ptr := llvm.LLVMBuildGlobalStringPtr(ctx.builder, fmt_c, "fmt")

	arg_count := 1 + arg_idx
	printf_args := make([]llvm.ValueRef, arg_count)
	defer delete(printf_args)
	printf_args[0] = fmt_ptr

	arg_types := make([]llvm.TypeRef, arg_count)
	defer delete(arg_types)
	arg_types[0] = llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)

	arg_idx = 0
	for i := 1; i < arg_count; i += 1 {
		if arg_idx < len(args) {
			av := generate_llvm_expr(ctx, args[arg_idx])
			printf_args[i] = av.val
			arg_types[i] = av.ty
			arg_idx += 1
		}
	}

	printf_ty := llvm.LLVMFunctionType(llvm.LLVMInt32Type(), raw_data(arg_types), uint(arg_count), 1)
	call := llvm.LLVMBuildCall2(
		ctx.builder,
		printf_ty,
		printf_fn,
		raw_data(printf_args),
		uint(arg_count),
		"printftmp",
	)

	return call
}

generate_llvm_print :: proc(ctx: ^CompilerCtx, args: []^ast.Node) -> llvm.ValueRef {
	// Declare printf if needed: int printf(const char*, ...).
	printf_name := strings.clone_to_cstring("printf")
	defer delete(printf_name)
	printf_fn := llvm.LLVMGetNamedFunction(ctx.module, printf_name)
	if printf_fn == nil {
		i8ptr := llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
		param_tys := make([]llvm.TypeRef, 1)
		defer delete(param_tys)
		param_tys[0] = i8ptr
		printf_ty := llvm.LLVMFunctionType(llvm.LLVMInt32Type(), raw_data(param_tys), 1, 1) // varargs
		printf_fn = llvm.LLVMAddFunction(ctx.module, printf_name, printf_ty)
	}

	last := llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, 0)
	if args == nil {
		return last
	}

	for arg in args {
		av := generate_llvm_expr(ctx, arg)

		fmt_str := "%d\n"
		if av.ty == llvm.LLVMDoubleType() {
			fmt_str = "%f\n"
		} else {
			i8ptr := llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
			if av.ty == i8ptr {
				fmt_str = "%s\n"
			} else if av.ty == llvm.LLVMInt1Type() {
				av.val = llvm.LLVMBuildZExt(ctx.builder, av.val, llvm.LLVMInt32Type(), "bool_to_int")
				av.ty = llvm.LLVMInt32Type()
			}
		}

		fmt_c := strings.clone_to_cstring(fmt_str)
		fmt_ptr := llvm.LLVMBuildGlobalStringPtr(ctx.builder, fmt_c, "fmt")
		delete(fmt_c)

		printf_args := make([]llvm.ValueRef, 2)
		defer delete(printf_args)
		printf_args[0] = fmt_ptr
		printf_args[1] = av.val
		i8ptr := llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)
		printf_param_tys := make([]llvm.TypeRef, 1)
		defer delete(printf_param_tys)
		printf_param_tys[0] = i8ptr
		printf_ty := llvm.LLVMFunctionType(llvm.LLVMInt32Type(), raw_data(printf_param_tys), 1, 1) // varargs
		call := llvm.LLVMBuildCall2(
			ctx.builder,
			printf_ty,
			printf_fn,
			raw_data(printf_args),
			2,
			"printtmp",
		)
		last = call
	}

	return last
}

generate_llvm_expr :: proc(ctx: ^CompilerCtx, node: ^ast.Node) -> ValueInfo {
	if node == nil {
		return ValueInfo{val = nil, ty = llvm.LLVMInt32Type()}
	}

	#partial switch node.kind {
	case .Int_Literal:
		return ValueInfo {
			val = llvm.LLVMConstInt(llvm.LLVMInt32Type(), u64(node.int_value), 0),
			ty = llvm.LLVMInt32Type(),
		}
	case .Float_Literal:
		return ValueInfo {
			val = llvm.LLVMConstReal(llvm.LLVMDoubleType(), node.float_value),
			ty = llvm.LLVMDoubleType(),
		}
	case .Bool_Literal:
		b := 0
		if node.bool_value {b = 1}
		return ValueInfo {
			val = llvm.LLVMConstInt(llvm.LLVMInt1Type(), u64(b), 0),
			ty = llvm.LLVMInt1Type(),
		}
	case .String_Literal:
		str_c := strings.clone_to_cstring(node.string_value)
		ptr := llvm.LLVMBuildGlobalStringPtr(ctx.builder, str_c, "str")
		delete(str_c)
		return ValueInfo{val = ptr, ty = llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)}
	case .Char_Literal:
		return ValueInfo {
			val = llvm.LLVMConstInt(llvm.LLVMInt32Type(), u64(node.int_value), 0),
			ty = llvm.LLVMInt32Type(),
		}
	case .Array_Literal:
		elem_count := len(node.elements)
		if elem_count == 0 {
			null_ptr := llvm.LLVMBuildBitCast(
				ctx.builder,
				llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, 0),
				llvm.LLVMPointerType(llvm.LLVMInt32Type(), 0),
				"null",
			)
			return ValueInfo{val = null_ptr, ty = llvm.LLVMPointerType(llvm.LLVMInt32Type(), 0)}
		}

		array_ptr := llvm.LLVMBuildArrayAlloca(
			ctx.builder,
			llvm.LLVMInt32Type(),
			llvm.LLVMConstInt(llvm.LLVMInt32Type(), u64(elem_count), 0),
			"array_tmp",
		)

		for i := 0; i < elem_count; i += 1 {
			elem_val := generate_llvm_expr(ctx, node.elements[i])
			if elem_val.ty == llvm.LLVMDoubleType() {
				elem_val.val = llvm.LLVMBuildFPToSI(
					ctx.builder,
					elem_val.val,
					llvm.LLVMInt32Type(),
					"ftoi",
				)
			}
			idx := llvm.LLVMConstInt(llvm.LLVMInt32Type(), u64(i), 0)
			indices := []llvm.ValueRef{idx}
			elem_ptr := llvm.LLVMBuildInBoundsGEP2(
				ctx.builder,
				llvm.LLVMInt32Type(),
				array_ptr,
				raw_data(indices),
				1,
				"array_elem_ptr",
			)
			llvm.LLVMBuildStore(ctx.builder, elem_val.val, elem_ptr)
		}

		return ValueInfo{val = array_ptr, ty = llvm.LLVMPointerType(llvm.LLVMInt32Type(), 0)}

	case .Struct_Literal:
		struct_ty := get_llvm_type(node.name)
		if struct_ty == nil {
			fmt.printf("ERROR: struct type not found: %s\n", node.name)
			return ValueInfo{val = nil, ty = llvm.LLVMInt32Type()}
		}
		if node.fields != nil && len(node.fields) > 0 {
			struct_ptr := llvm.LLVMBuildAlloca(ctx.builder, struct_ty, "struct_tmp")
			for i in 0..<len(node.fields) {
				field_val := generate_llvm_expr(ctx, node.fields[i].value)
				field_name_c := strings.clone_to_cstring(node.fields[i].name)
				field_ptr := llvm.LLVMBuildStructGEP2(ctx.builder, struct_ty, struct_ptr, uint(i), field_name_c)
				delete(field_name_c)
				field_elem_ty := llvm.LLVMStructGetTypeAtIndex(struct_ty, uint(i))
				if field_val.ty != field_elem_ty {
					field_val.val = convert_type(ctx, field_val.val, field_val.ty, field_elem_ty)
				}
				llvm.LLVMBuildStore(ctx.builder, field_val.val, field_ptr)
			}
			return ValueInfo{val = struct_ptr, ty = struct_ty}
		}
		return ValueInfo{val = nil, ty = struct_ty}

	case .Member_Expr:
		if node.object.kind == .Ident {
			if val, found := find_enum_variant_value(node.object.name, node.field); found {
				int_val := llvm.LLVMConstInt(llvm.LLVMInt32Type(), cast(u64)val, 0)
				return ValueInfo{val = int_val, ty = llvm.LLVMInt32Type(), base_type = "int"}
			}
			if _, has_fn := fn_types[node.field]; has_fn {
				fn_name_c := strings.clone_to_cstring(node.field)
				fn_val := llvm.LLVMGetNamedFunction(ctx.module, fn_name_c)
				delete(fn_name_c)
				if fn_val != nil {
					fn_ty := llvm.LLVMTypeOf(fn_val)
					fn_ptr_ty := llvm.LLVMPointerType(fn_ty, 0)
					fn_ptr := llvm.LLVMBuildBitCast(ctx.builder, fn_val, fn_ptr_ty, "fn_ptr")
					return ValueInfo{val = fn_ptr, ty = fn_ptr_ty}
				}
			}
			if gv, ok := global_consts[node.field]; ok {
				init_val := llvm.LLVMGetInitializer(gv)
				loaded_ptr := llvm.LLVMBuildAlloca(ctx.builder, llvm.LLVMTypeOf(init_val), "const_tmp")
				llvm.LLVMBuildStore(ctx.builder, init_val, loaded_ptr)
				name_c := strings.clone_to_cstring(node.field)
				loaded_val := llvm.LLVMBuildLoad2(ctx.builder, llvm.LLVMTypeOf(init_val), loaded_ptr, name_c)
				delete(name_c)
				return ValueInfo{val = loaded_val, ty = llvm.LLVMTypeOf(init_val)}
			}
		}

		obj_val := generate_llvm_expr(ctx, node.object)
		obj_ptr := obj_val.val
		if obj_ptr == nil {
			fmt.printf("ERROR: member access on nil object\n")
			return ValueInfo{val = llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, 0), ty = llvm.LLVMInt32Type()}
		}
		obj_ty := obj_val.ty
		if obj_ty == nil {
			fmt.printf("ERROR: member access on unknown type\n")
			return ValueInfo{val = llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, 0), ty = llvm.LLVMInt32Type()}
		}
		kind := llvm.LLVMGetTypeKind(obj_ty)
		if kind != .PointerTypeKind {
			if obj_val.struct_type != "" {
				// For struct variables, obj_ptr is the alloca - use it directly
			} else {
				loaded_ptr := llvm.LLVMBuildAlloca(ctx.builder, obj_ty, "obj_tmp")
				llvm.LLVMBuildStore(ctx.builder, obj_ptr, loaded_ptr)
				obj_ptr = loaded_ptr
			}
		}
		struct_name := ""
		if node.object.kind == .Ident {
			_, _, _, struct_name, _ = find_var(ctx, node.object.name)
		} else if obj_val.struct_type != "" {
			struct_name = obj_val.struct_type
		}
		if struct_name == "" && obj_val.ty != nil {
			kind := llvm.LLVMGetTypeKind(obj_val.ty)
			if kind == .StructTypeKind {
				for sn, st in struct_types {
					if st == obj_val.ty {
						struct_name = sn
						break
					}
				}
			}
		}
		if struct_name == "" {
			struct_name = obj_val.struct_type
		}
		field_idx := find_struct_field_index(struct_name, node.field)
		if field_idx < 0 || obj_ty == nil {
			fmt.printf("ERROR: field '%s' not found in struct '%s' (obj_ty=%p)\n", node.field, struct_name, obj_ty)
			return ValueInfo{val = llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, 0), ty = llvm.LLVMInt32Type()}
		}
		field_name_c := strings.clone_to_cstring(node.field)
		field_ptr := llvm.LLVMBuildStructGEP2(ctx.builder, obj_ty, obj_ptr, uint(field_idx), field_name_c)
		delete(field_name_c)
		field_elem_ty := llvm.LLVMStructGetTypeAtIndex(obj_ty, uint(field_idx))
		loaded_val := llvm.LLVMBuildLoad2(ctx.builder, field_elem_ty, field_ptr, "field_val")
		return ValueInfo{val = loaded_val, ty = field_elem_ty, base_type = "int"}

	case .Index_Expr:
		arr_val := generate_llvm_expr(ctx, node.object)
		idx_val := generate_llvm_expr(ctx, node.value)

		if idx_val.ty == llvm.LLVMDoubleType() {
			idx_val.val = llvm.LLVMBuildFPToSI(
				ctx.builder,
				idx_val.val,
				llvm.LLVMInt32Type(),
				"ftoi",
			)
		}

		indices := []llvm.ValueRef{idx_val.val}
		elem_ptr := llvm.LLVMBuildInBoundsGEP2(
			ctx.builder,
			llvm.LLVMInt32Type(),
			arr_val.val,
			raw_data(indices),
			1,
			"index_ptr",
		)
		loaded_val := llvm.LLVMBuildLoad2(ctx.builder, llvm.LLVMInt32Type(), elem_ptr, "index_val")
		return ValueInfo{val = loaded_val, ty = llvm.LLVMInt32Type()}

	case .Ident:
		vi_ptr, vi_ty, vi_base_type, vi_struct_type, found := find_var(ctx, node.name)
		if !found {
			if gv, ok := global_consts[node.name]; ok {
				init_val := llvm.LLVMGetInitializer(gv)
				loaded_ptr := llvm.LLVMBuildAlloca(ctx.builder, llvm.LLVMTypeOf(init_val), "const_tmp")
				llvm.LLVMBuildStore(ctx.builder, init_val, loaded_ptr)
				name_c := strings.clone_to_cstring(node.name)
				loaded_val := llvm.LLVMBuildLoad2(ctx.builder, llvm.LLVMTypeOf(init_val), loaded_ptr, name_c)
				delete(name_c)
				return ValueInfo{val = loaded_val, ty = llvm.LLVMTypeOf(init_val)}
			}
		}
		if found {
			if vi_struct_type != "" || vi_base_type != "" {
				check_struct_type := vi_struct_type
				if check_struct_type == "" {
					check_struct_type = vi_base_type
				}
				if _, ok := struct_types[check_struct_type]; ok {
					return ValueInfo {
						val = vi_ptr,
						ty = vi_ty,
						struct_type = check_struct_type,
					}
				}
			}
			name_c := strings.clone_to_cstring(node.name)
			val := llvm.LLVMBuildLoad2(
				ctx.builder,
				vi_ty,
				vi_ptr,
				name_c,
			)
			delete(name_c)
			return ValueInfo {
				val = val,
				ty = vi_ty,
			}
		}
		return ValueInfo {
			val = llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, 0),
			ty = llvm.LLVMInt32Type(),
		}
	case .Unary_Expr:
		operand := generate_llvm_expr(ctx, node.operand)
		if node.operator == "!" {
			cond_i1 := to_bool_i1(ctx, operand)
			zero_i1 := llvm.LLVMConstInt(llvm.LLVMInt1Type(), 0, 0)
			LLVMIntEQ: c.int = 32
			not_i1 := llvm.LLVMBuildICmp(ctx.builder, LLVMIntEQ, cond_i1, zero_i1, "not")
			return ValueInfo{val = zext_i1_to_i32(ctx, not_i1), ty = llvm.LLVMInt32Type()}
		}
		if node.operator == "-" {
			if operand.ty == llvm.LLVMDoubleType() {
				zero := llvm.LLVMConstReal(llvm.LLVMDoubleType(), 0.0)
				return ValueInfo {
					val = llvm.LLVMBuildFSub(ctx.builder, zero, operand.val, "fneg"),
					ty = llvm.LLVMDoubleType(),
				}
			}
			zero := llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, 0)
			return ValueInfo {
				val = llvm.LLVMBuildSub(ctx.builder, zero, operand.val, "neg"),
				ty = llvm.LLVMInt32Type(),
			}
		}
		if node.operator == "&" {
			// For address-of, we need to find the variable's storage pointer
			if node.operand.kind == .Ident {
				var_ptr, var_ty, var_base_type, _, found := find_var(ctx, node.operand.name)
				if found {
					// Create pointer to the underlying type
					elem_ty := var_ty
					if var_base_type == "float" {
						elem_ty = llvm.LLVMDoubleType()
					}
					ptr_ty := llvm.LLVMPointerType(elem_ty, 0)
					return ValueInfo {
						val = var_ptr,
						ty = ptr_ty,
					}
				}
			}
			// Fallback
			ptr_ty := llvm.LLVMPointerType(operand.ty, 0)
			return ValueInfo {
				val = operand.val,
				ty = ptr_ty,
			}
		}
		if node.operator == "^" {
			// Dereference: load from pointer
			// operand.val is a pointer (LLVM pointer type), load the value it points to
			load_ty := get_llvm_type(operand.base_type)
			return ValueInfo {
				val = llvm.LLVMBuildLoad2(ctx.builder, load_ty, operand.val, "deref"),
				ty = load_ty,
			}
		}
		return operand
	case .Binary_Expr:
		left := generate_llvm_expr(ctx, node.left)
		right := generate_llvm_expr(ctx, node.right)

		// Arithmetic.
		if node.operator == "+" ||
		   node.operator == "-" ||
		   node.operator == "*" ||
		   node.operator == "/" ||
		   node.operator == "%" {
			// Promote to float if needed (not for modulo).
			if node.operator != "%" {
				if left.ty == llvm.LLVMDoubleType() && right.ty == llvm.LLVMInt32Type() {
					right.val = llvm.LLVMBuildSIToFP(
						ctx.builder,
						right.val,
						llvm.LLVMDoubleType(),
						"itof",
					)
					right.ty = llvm.LLVMDoubleType()
				} else if left.ty == llvm.LLVMInt32Type() && right.ty == llvm.LLVMDoubleType() {
					left.val = llvm.LLVMBuildSIToFP(
						ctx.builder,
						left.val,
						llvm.LLVMDoubleType(),
						"itof",
					)
					left.ty = llvm.LLVMDoubleType()
				}
			}

			if left.ty == llvm.LLVMDoubleType() {
				if node.operator ==
				   "+" {return ValueInfo{val = llvm.LLVMBuildFAdd(ctx.builder, left.val, right.val, "fadd"), ty = llvm.LLVMDoubleType()}}
				if node.operator ==
				   "-" {return ValueInfo{val = llvm.LLVMBuildFSub(ctx.builder, left.val, right.val, "fsub"), ty = llvm.LLVMDoubleType()}}
				if node.operator ==
				   "*" {return ValueInfo{val = llvm.LLVMBuildFMul(ctx.builder, left.val, right.val, "fmul"), ty = llvm.LLVMDoubleType()}}
				return ValueInfo {
					val = llvm.LLVMBuildFDiv(ctx.builder, left.val, right.val, "fdiv"),
					ty = llvm.LLVMDoubleType(),
				}
			}

			if node.operator ==
			   "+" {return ValueInfo{val = llvm.LLVMBuildAdd(ctx.builder, left.val, right.val, "addtmp"), ty = llvm.LLVMInt32Type()}}
			if node.operator ==
			   "-" {return ValueInfo{val = llvm.LLVMBuildSub(ctx.builder, left.val, right.val, "subtmp"), ty = llvm.LLVMInt32Type()}}
			if node.operator ==
			   "*" {return ValueInfo{val = llvm.LLVMBuildMul(ctx.builder, left.val, right.val, "multmp"), ty = llvm.LLVMInt32Type()}}
			if node.operator == "%" {
				return ValueInfo{val = llvm.LLVMBuildSRem(ctx.builder, left.val, right.val, "remtmp"), ty = llvm.LLVMInt32Type()}
			}
			return ValueInfo {
				val = llvm.LLVMBuildSDiv(ctx.builder, left.val, right.val, "divtmp"),
				ty = llvm.LLVMInt32Type(),
			}
		}

		// Logical operators: && and ||.
		if node.operator == "&&" || node.operator == "||" {
			li1 := to_bool_i1(ctx, left)
			ri1 := to_bool_i1(ctx, right)
			if node.operator == "&&" {
				res_i1 := llvm.LLVMBuildAnd(ctx.builder, li1, ri1, "andtmp")
				return ValueInfo{val = zext_i1_to_i32(ctx, res_i1), ty = llvm.LLVMInt32Type()}
			}
			res_i1 := llvm.LLVMBuildOr(ctx.builder, li1, ri1, "ortmp")
			return ValueInfo{val = zext_i1_to_i32(ctx, res_i1), ty = llvm.LLVMInt32Type()}
		}

		// Comparisons.
		is_float := left.ty == llvm.LLVMDoubleType() || right.ty == llvm.LLVMDoubleType()

		// LLVM real predicate numeric values (LLVMRealPredicate).
		LLVMRealOEQ: c.int = 0
		LLVMRealONE: c.int = 1
		LLVMRealOGT: c.int = 2
		LLVMRealOGE: c.int = 3
		LLVMRealOLT: c.int = 4
		LLVMRealOLE: c.int = 5

		if is_float {
			// Promote ints to doubles.
			if left.ty == llvm.LLVMInt32Type() {
				left.val = llvm.LLVMBuildSIToFP(
					ctx.builder,
					left.val,
					llvm.LLVMDoubleType(),
					"itof",
				)
				left.ty = llvm.LLVMDoubleType()
			}
			if right.ty == llvm.LLVMInt32Type() {
				right.val = llvm.LLVMBuildSIToFP(
					ctx.builder,
					right.val,
					llvm.LLVMDoubleType(),
					"itof",
				)
				right.ty = llvm.LLVMDoubleType()
			}

			op: c.int = LLVMRealOEQ
			if node.operator ==
			   "==" {op = LLVMRealOEQ} else if node.operator == "!=" {op = LLVMRealONE} else if node.operator == ">" {op = LLVMRealOGT} else if node.operator == ">=" {op = LLVMRealOGE} else if node.operator == "<" {op = LLVMRealOLT} else if node.operator == "<=" {op = LLVMRealOLE}

			cond_i1 := llvm.LLVMBuildFCmp(ctx.builder, op, left.val, right.val, "fcmp")
			return ValueInfo{val = zext_i1_to_i32(ctx, cond_i1), ty = llvm.LLVMInt32Type()}
		}

		op: c.int = LLVMIntEQ
		if node.operator ==
		   "==" {op = LLVMIntEQ} else if node.operator == "!=" {op = LLVMIntNE} else if node.operator == ">" {op = LLVMIntSGT} else if node.operator == ">=" {op = LLVMIntSGE} else if node.operator == "<" {op = LLVMIntSLT} else if node.operator == "<=" {op = LLVMIntSLE}

		if left.ty != right.ty {
			target_ty := llvm.LLVMInt32Type()
			if left.ty == target_ty {
				right.val = convert_type(ctx, right.val, right.ty, target_ty)
				right.ty = target_ty
			} else if right.ty == target_ty {
				left.val = convert_type(ctx, left.val, left.ty, target_ty)
				left.ty = target_ty
			}
		}

		cond_i1 := llvm.LLVMBuildICmp(ctx.builder, op, left.val, right.val, "icmp")
		return ValueInfo{val = zext_i1_to_i32(ctx, cond_i1), ty = llvm.LLVMInt32Type()}

	case .Call_Expr:
		// Builtin: print / println / printf
		if node.callee != nil && node.callee.kind == .Ident {
			fn_name := node.callee.name
			if fn_name == "print" || fn_name == "println" {
				return ValueInfo {
					val = generate_llvm_print(ctx, node.arguments),
					ty = llvm.LLVMInt32Type(),
				}
			}
			if fn_name == "printf" && len(node.arguments) > 0 && node.arguments[0].kind == .String_Literal {
				return ValueInfo {
					val = generate_llvm_printf(ctx, node.arguments[0].string_value, node.arguments[1:]),
					ty = llvm.LLVMInt32Type(),
				}
			}
			if fn_name == "read_line" {
				result_val := generate_llvm_read_line(ctx)
				return ValueInfo {
					val = result_val.val,
					ty = result_val.ty,
				}
			}
			if fn_name == "input" {
				result_val := generate_llvm_input(ctx)
				return ValueInfo {
					val = result_val.val,
					ty = result_val.ty,
				}
			}
		}

		// Regular calls (callee must be identifier).
		if node.callee != nil && node.callee.kind == .Ident {
			callee_name := node.callee.name
			callee_name_c := strings.clone_to_cstring(callee_name)
			defer delete(callee_name_c)
			fn_val := llvm.LLVMGetNamedFunction(ctx.module, callee_name_c)

			// Handle generic function type resolution
			fn_info, has_fn := fn_types[callee_name]
			ret_type: llvm.TypeRef
			param_tys: []llvm.TypeRef

			if has_fn {
				ret_type = fn_info.ret_type
				param_tys = fn_info.param_types

				// If calling with explicit generic args, resolve concrete types
				if len(node.callee.generic_args) > 0 && node.callee.generic_args != nil {
					// Use the first generic arg to determine return type
					if len(node.callee.generic_args) > 0 {
						first_arg := node.callee.generic_args[0]
						ret_type = get_llvm_type(first_arg.name)
						
						// Also substitute param types for generic params
						for i := 0; i < len(param_tys); i += 1 {
							param_tys[i] = get_llvm_type(first_arg.name)
						}
					}
				}
			} else {
				ret_type = llvm.LLVMInt32Type()
				param_tys = make([]llvm.TypeRef, 0)
			}

			arg_count: uint = 0
			if node.arguments != nil {
				arg_count = uint(len(node.arguments))
			}

			arg_vals := make([]llvm.ValueRef, int(arg_count))
			defer delete(arg_vals)

			for i in 0 ..< arg_count {
				av := generate_llvm_expr(ctx, node.arguments[i])
				if has_fn && i < uint(len(param_tys)) {
					if av.ty != param_tys[i] {
						arg_vals[i] = convert_type(ctx, av.val, av.ty, param_tys[i])
					} else {
						arg_vals[i] = av.val
					}
				} else {
					arg_vals[i] = av.val
				}
			}

			call_ty := llvm.LLVMFunctionType(
				ret_type,
				raw_data(param_tys),
				arg_count,
				0,
			)

			if fn_val == nil {
				fn_val = llvm.LLVMAddFunction(ctx.module, callee_name_c, call_ty)
			}

			call := llvm.LLVMBuildCall2(
				ctx.builder,
				call_ty,
				fn_val,
				raw_data(arg_vals),
				arg_count,
				"calltmp",
			)
			return ValueInfo{val = call, ty = ret_type}
		}

		// Handle calls on member expressions (e.g., math.sqrt())
		if node.callee != nil && node.callee.kind == .Member_Expr {
			fn_name := node.callee.field
			fn_name_c := strings.clone_to_cstring(fn_name)
			defer delete(fn_name_c)
			fn_val := llvm.LLVMGetNamedFunction(ctx.module, fn_name_c)

			fn_info, has_fn := fn_types[fn_name]
			ret_type: llvm.TypeRef
			param_tys: []llvm.TypeRef

			if has_fn {
				ret_type = fn_info.ret_type
				param_tys = fn_info.param_types
			} else {
				ret_type = llvm.LLVMInt64Type()
				param_tys = make([]llvm.TypeRef, 0)
			}

			arg_count: uint = 0
			if node.arguments != nil {
				arg_count = uint(len(node.arguments))
			}

			arg_vals := make([]llvm.ValueRef, int(arg_count))
			defer delete(arg_vals)

			for i in 0 ..< arg_count {
				av := generate_llvm_expr(ctx, node.arguments[i])
				if has_fn && i < uint(len(param_tys)) {
					if av.ty != param_tys[i] {
						arg_vals[i] = convert_type(ctx, av.val, av.ty, param_tys[i])
					} else {
						arg_vals[i] = av.val
					}
				} else {
					arg_vals[i] = av.val
				}
			}

			call_ty := llvm.LLVMFunctionType(
				ret_type,
				raw_data(param_tys),
				arg_count,
				0,
			)

			if fn_val == nil {
				fn_val = llvm.LLVMAddFunction(ctx.module, fn_name_c, call_ty)
			}

			call := llvm.LLVMBuildCall2(
				ctx.builder,
				call_ty,
				fn_val,
				raw_data(arg_vals),
				arg_count,
				"calltmp",
			)
			return ValueInfo{val = call, ty = ret_type}
		}

		return ValueInfo {
			val = llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, 0),
			ty = llvm.LLVMInt32Type(),
		}
	}

	return ValueInfo {
		val = llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, 0),
		ty = llvm.LLVMInt32Type(),
	}
}
