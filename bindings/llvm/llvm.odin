package llvm

foreign import LLVM_C "libLLVM.so"

import "core:c"

// Core types
ContextRef :: distinct rawptr
ModuleRef :: distinct rawptr
TypeRef :: distinct rawptr
ValueRef :: distinct rawptr
BasicBlockRef :: distinct rawptr
BuilderRef :: distinct rawptr

// VerifierFailureAction
VerifierFailureAction :: enum i32 {
	AbortProcessAction,
	PrintMessageAction,
	ReturnStatusAction,
}

// Type kinds
TypeKind :: enum i32 {
	VoidTypeKind,
	HalfTypeKind,
	FloatTypeKind,
	DoubleTypeKind,
	X86_FP80TypeKind,
	FP128TypeKind,
	PPC_FP128TypeKind,
	LabelTypeKind,
	IntegerTypeKind,
	FunctionTypeKind,
	StructTypeKind,
	ArrayTypeKind,
	PointerTypeKind,
	VectorTypeKind,
	MetadataTypeKind,
	X86_MMXTypeKind,
	TokenTypeKind,
	ScalableVectorTypeKind,
	BFloatTypeKind,
	X86_AMXTypeKind,
	TargetExtTypeKind,
}

// Context APIs
@(default_calling_convention = "c")
foreign LLVM_C {
	// Context
	LLVMContextCreate :: proc() -> ContextRef ---
	LLVMContextDispose :: proc(Context: ContextRef) ---
	LLVMGetGlobalContext :: proc() -> ContextRef ---

	// Module
	LLVMModuleCreateWithName :: proc(ModuleID: cstring) -> ModuleRef ---
	LLVMModuleCreateWithNameInContext :: proc(ModuleID: cstring, Context: ContextRef) -> ModuleRef ---
	LLVMDisposeModule :: proc(Module: ModuleRef) ---
	LLVMPrintModuleToFile :: proc(Module: ModuleRef, Filename: cstring, ErrorMessage: ^cstring) -> int ---
	LLVMPrintModuleToString :: proc(Module: ModuleRef) -> cstring ---
	LLVMDisposeMessage :: proc(Message: cstring) ---

	// Types
	LLVMVoidType :: proc() -> TypeRef ---
	LLVMInt1Type :: proc() -> TypeRef ---
	LLVMInt8Type :: proc() -> TypeRef ---
	LLVMInt16Type :: proc() -> TypeRef ---
	LLVMInt32Type :: proc() -> TypeRef ---
	LLVMInt64Type :: proc() -> TypeRef ---
	LLVMIntType :: proc(NumBits: uint) -> TypeRef ---
	LLVMFloatType :: proc() -> TypeRef ---
	LLVMDoubleType :: proc() -> TypeRef ---
	LLVMPointerType :: proc(ElementType: TypeRef, AddressSpace: uint) -> TypeRef ---
	LLVMFunctionType :: proc(ReturnType: TypeRef, ParamTypes: [^]TypeRef, ParamCount: uint, IsVarArg: int) -> TypeRef ---
	LLVMGetTypeKind :: proc(Ty: TypeRef) -> TypeKind ---
	LLVMStructCreateNamed :: proc(Context: ContextRef, Name: cstring) -> TypeRef ---
	LLVMStructSetBody :: proc(StructType: TypeRef, ElementTypes: [^]TypeRef, Count: uint, Packed: int) ---
	LLVMStructGetTypeAtIndex :: proc(StructType: TypeRef, Index: uint) -> TypeRef ---
	LLVMGetStructType :: proc(StructType: TypeRef) -> TypeRef ---

	// Values - Functions
	LLVMAddFunction :: proc(Module: ModuleRef, Name: cstring, FunctionTy: TypeRef) -> ValueRef ---
	LLVMGetNamedFunction :: proc(Module: ModuleRef, Name: cstring) -> ValueRef ---
	LLVMGetNamedGlobal :: proc(Module: ModuleRef, Name: cstring) -> ValueRef ---
	LLVMAddGlobal :: proc(Module: ModuleRef, Ty: TypeRef, Name: cstring) -> ValueRef ---
	LLVMSetGlobalConstant :: proc(GlobalVar: ValueRef, IsConstant: bool) ---
	LLVMSetInitializer :: proc(GlobalVar: ValueRef, ConstVal: ValueRef) ---
	LLVMGetInitializer :: proc(GlobalVar: ValueRef) -> ValueRef ---
	LLVMTypeOf :: proc(Val: ValueRef) -> TypeRef ---
	LLVMGetFirstFunction :: proc(Module: ModuleRef) -> ValueRef ---
	LLVMGetNextFunction :: proc(Fn: ValueRef) -> ValueRef ---

	// Values - Constants
	LLVMConstInt :: proc(Ty: TypeRef, N: u64, SignExtend: int) -> ValueRef ---
	LLVMConstReal :: proc(Ty: TypeRef, N: f64) -> ValueRef ---

	// Basic Blocks
	LLVMAppendBasicBlock :: proc(Fn: ValueRef, Name: cstring) -> BasicBlockRef ---
	LLVMInsertBasicBlock :: proc(BB: BasicBlockRef, Name: cstring) -> BasicBlockRef ---
	LLVMGetFirstBasicBlock :: proc(Fn: ValueRef) -> BasicBlockRef ---
	LLVMGetNextBasicBlock :: proc(BB: BasicBlockRef) -> BasicBlockRef ---

	// Builder
	LLVMCreateBuilder :: proc() -> BuilderRef ---
	LLVMDisposeBuilder :: proc(Builder: BuilderRef) ---
	LLVMPositionBuilderAtEnd :: proc(Builder: BuilderRef, Block: BasicBlockRef) ---
	LLVMPositionBuilderBefore :: proc(Builder: BuilderRef, Instr: ValueRef) ---

	// Instructions - Terminators
	LLVMBuildRetVoid :: proc(Builder: BuilderRef) -> ValueRef ---
	LLVMBuildRet :: proc(Builder: BuilderRef, V: ValueRef) -> ValueRef ---
	LLVMBuildBr :: proc(Builder: BuilderRef, Dest: BasicBlockRef) -> ValueRef ---
	LLVMBuildCondBr :: proc(Builder: BuilderRef, If: ValueRef, Then: BasicBlockRef, Else: BasicBlockRef) -> ValueRef ---
	LLVMBuildSwitch :: proc(Builder: BuilderRef, V: ValueRef, Else: BasicBlockRef, NumCases: uint) -> ValueRef ---

	// Instructions - Memory
	LLVMBuildAlloca :: proc(Builder: BuilderRef, Ty: TypeRef, Name: cstring) -> ValueRef ---
	LLVMBuildArrayAlloca :: proc(Builder: BuilderRef, Ty: TypeRef, Val: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildLoad :: proc(Builder: BuilderRef, Pointer: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildStore :: proc(Builder: BuilderRef, Val: ValueRef, Ptr: ValueRef) -> ValueRef ---
	LLVMBuildInBoundsGEP2 :: proc(Builder: BuilderRef, Ty: TypeRef, Pointer: ValueRef, Indices: [^]ValueRef, NumIndices: uint, Name: cstring) -> ValueRef ---
	LLVMBuildStructGEP2 :: proc(Builder: BuilderRef, Ty: TypeRef, Pointer: ValueRef, Index: uint, Name: cstring) -> ValueRef ---

	// Newer LLVM C API (LLVM 15+): Load2 requires the destination type explicitly.
	LLVMBuildLoad2 :: proc(Builder: BuilderRef, Ty: TypeRef, Pointer: ValueRef, Name: cstring) -> ValueRef ---

	// Global strings
	LLVMBuildGlobalStringPtr :: proc(Builder: BuilderRef, Str: cstring, Name: cstring) -> ValueRef ---

	// Instructions - Arithmetic
	LLVMBuildAdd :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildFAdd :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildSub :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildFSub :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildMul :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildFMul :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildUDiv :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildSDiv :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildFDiv :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildURem :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildSRem :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildFRem :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---

	// Instructions - Logical
	LLVMBuildAnd :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildOr :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildXor :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildShl :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildLShr :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildAShr :: proc(Builder: BuilderRef, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---

	// Instructions - Cast
	LLVMBuildZExt :: proc(Builder: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	LLVMBuildSExt :: proc(Builder: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	LLVMBuildFPToUI :: proc(Builder: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	LLVMBuildFPToSI :: proc(Builder: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	LLVMBuildUIToFP :: proc(Builder: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	LLVMBuildSIToFP :: proc(Builder: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	LLVMBuildTrunc :: proc(Builder: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	LLVMBuildBitCast :: proc(Builder: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	LLVMBuildPtrToInt :: proc(Builder: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---
	LLVMBuildIntToPtr :: proc(Builder: BuilderRef, Val: ValueRef, DestTy: TypeRef, Name: cstring) -> ValueRef ---

	// Instructions - Other
	LLVMBuildICmp :: proc(Builder: BuilderRef, Op: c.int, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildFCmp :: proc(Builder: BuilderRef, Op: c.int, LHS: ValueRef, RHS: ValueRef, Name: cstring) -> ValueRef ---
	LLVMBuildPhi :: proc(Builder: BuilderRef, Ty: TypeRef, Name: cstring) -> ValueRef ---
	LLVMBuildCall :: proc(Builder: BuilderRef, Fn: ValueRef, Args: [^]ValueRef, NumArgs: uint, Name: cstring) -> ValueRef ---
	LLVMBuildCall2 :: proc(Builder: BuilderRef, FnTy: TypeRef, Fn: ValueRef, Args: [^]ValueRef, NumArgs: uint, Name: cstring) -> ValueRef ---
	LLVMBuildSelect :: proc(Builder: BuilderRef, If: ValueRef, Then: ValueRef, Else: ValueRef, Name: cstring) -> ValueRef ---

	// Get parameters
	LLVMGetParam :: proc(Fn: ValueRef, ArgNo: uint) -> ValueRef ---

	// Verify module
	LLVMVerifyModule :: proc(Module: ModuleRef, Action: VerifierFailureAction, OutMessage: ^cstring) -> int ---

	// Write bitcode
	LLVMWriteBitcodeToFile :: proc(Module: ModuleRef, Path: cstring) -> int ---

	// Get version
	LLVMGetVersion :: proc() -> uint ---
}
