package codegen_utils

import "core:c"
import "../../common"
import "core:strings"
import llvm "../../bindings/llvm"

verify_module :: proc(module: llvm.ModuleRef) -> bool {
	err_msg: cstring
	result := llvm.LLVMVerifyModule(module, llvm.VerifierFailureAction.ReturnStatusAction, &err_msg)
	if result != 0 {
		if err_msg != nil {
			err_str := string(err_msg)
			if len(err_str) > 0 {
				common.colorf(.Red, "Module verification error: %s\n", err_str)
			}
			llvm.LLVMDisposeMessage(err_msg)
		}
		return false
	}
	return true
}

to_const0 :: proc(ty: llvm.TypeRef) -> llvm.ValueRef {
	if ty == llvm.LLVMInt32Type() || ty == llvm.LLVMInt8Type() || ty == llvm.LLVMInt16Type() || ty == llvm.LLVMInt64Type() {
		return llvm.LLVMConstInt(ty, 0, 0)
	}
	if ty == llvm.LLVMInt1Type() {
		return llvm.LLVMConstInt(llvm.LLVMInt1Type(), 0, 0)
	}
	if ty == llvm.LLVMDoubleType() {
		return llvm.LLVMConstReal(llvm.LLVMDoubleType(), 0.0)
	}
	if ty == llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0) {
		return llvm.LLVMConstInt(llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0), 0, 0)
	}
	return llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, 0)
}

LLVMIntEQ  :: cast(c.int) 32
LLVMIntNE  :: cast(c.int) 33
LLVMIntSGT :: cast(c.int) 38
LLVMIntSGE :: cast(c.int) 39
LLVMIntSLT :: cast(c.int) 40
LLVMIntSLE :: cast(c.int) 41

convert_type :: proc(builder: llvm.BuilderRef, val: llvm.ValueRef, from_ty, to_ty: llvm.TypeRef) -> llvm.ValueRef {
	if from_ty == to_ty {
		return val
	}
	
	from_kind := llvm.LLVMGetTypeKind(from_ty)
	to_kind := llvm.LLVMGetTypeKind(to_ty)
	
	is_from_int := from_kind == .IntegerTypeKind
	is_to_int := to_kind == .IntegerTypeKind
	
	if is_from_int && is_to_int {
		i32 := llvm.LLVMInt32Type()
		i64 := llvm.LLVMInt64Type()
		i8 := llvm.LLVMInt8Type()
		
		if from_ty == i32 && to_ty == i64 {
			return llvm.LLVMBuildSExt(builder, val, to_ty, "sext")
		}
		if from_ty == i64 && to_ty == i32 {
			return llvm.LLVMBuildTrunc(builder, val, to_ty, "trunc")
		}
		if from_ty == i8 && to_ty == i32 {
			return llvm.LLVMBuildSExt(builder, val, to_ty, "sext")
		}
		if from_ty == i8 && to_ty == i64 {
			return llvm.LLVMBuildSExt(builder, val, to_ty, "sext")
		}
		if from_ty == i32 && to_ty == i8 {
			return llvm.LLVMBuildTrunc(builder, val, to_ty, "trunc")
		}
		if from_ty == i64 && to_ty == i8 {
			return llvm.LLVMBuildTrunc(builder, val, to_ty, "trunc")
		}
		return val
	}
	
	is_from_float := from_kind == .FloatTypeKind || from_kind == .DoubleTypeKind
	is_to_float := to_kind == .FloatTypeKind || to_kind == .DoubleTypeKind
	
	if is_from_int && is_to_float {
		return llvm.LLVMBuildSIToFP(builder, val, to_ty, "itof")
	}
	
	if is_from_float && is_to_int {
		return llvm.LLVMBuildFPToSI(builder, val, to_ty, "ftoi")
	}
	
	return val
}

ValueInfo :: struct {
	val:         llvm.ValueRef,
	ty:          llvm.TypeRef,
	base_type:   string,
	struct_type: string,
}

to_bool_i1 :: proc(builder: llvm.BuilderRef, v: ValueInfo) -> llvm.ValueRef {
	zero := to_const0(v.ty)

	LLVMRealONE :: cast(c.int) 1

	if v.ty == llvm.LLVMInt1Type() {
		return v.val
	}
	if v.ty == llvm.LLVMInt32Type() {
		return llvm.LLVMBuildICmp(builder, LLVMIntNE, v.val, zero, "tobool")
	}
	if v.ty == llvm.LLVMDoubleType() {
		return llvm.LLVMBuildFCmp(builder, LLVMRealONE, v.val, zero, "tobool")
	}

	return llvm.LLVMBuildICmp(
		builder,
		LLVMIntNE,
		v.val,
		to_const0(llvm.LLVMInt32Type()),
		"tobool",
	)
}

zext_i1_to_i32 :: proc(builder: llvm.BuilderRef, cond_i1: llvm.ValueRef) -> llvm.ValueRef {
	return llvm.LLVMBuildZExt(builder, cond_i1, llvm.LLVMInt32Type(), "tobool_i32")
}

zext_i1_to_i64 :: proc(builder: llvm.BuilderRef, cond_i1: llvm.ValueRef) -> llvm.ValueRef {
	return llvm.LLVMBuildZExt(builder, cond_i1, llvm.LLVMInt64Type(), "tobool_i64")
}
