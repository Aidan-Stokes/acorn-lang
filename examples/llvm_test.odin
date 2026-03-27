package main

import "../bindings/llvm"
import "core:fmt"
import "core:os"

main :: proc() {
	fmt.println("=== Linux LLVM-Odin Binding Test ===")

	// Use global context
	ctx := llvm.LLVMGetGlobalContext()
	fmt.println("Using global LLVM context")

	module := llvm.LLVMModuleCreateWithName("test_module")
	if module == nil {
		fmt.eprintln("Failed to create module")
		os.exit(1)
	}
	fmt.println("Created module: test_module")

	// Create function type: i32 add(i32, i32)
	param_types := []llvm.TypeRef{llvm.LLVMInt32Type(), llvm.LLVMInt32Type()}
	fn_type := llvm.LLVMFunctionType(llvm.LLVMInt32Type(), raw_data(param_types), 2, 0)

	// Add function to module
	add_fn := llvm.LLVMAddFunction(module, "add", fn_type)
	fmt.println("Added function: add(i32, i32) -> i32")

	// Create entry basic block
	entry_bb := llvm.LLVMAppendBasicBlock(add_fn, "entry")

	// Create builder and position at end of entry block
	builder := llvm.LLVMCreateBuilder()
	llvm.LLVMPositionBuilderAtEnd(builder, entry_bb)
	fmt.println("Created builder and positioned at entry block")

	// Build: %result = %0 + %1
	param0 := llvm.LLVMGetParam(add_fn, 0)
	param1 := llvm.LLVMGetParam(add_fn, 1)
	result := llvm.LLVMBuildAdd(builder, param0, param1, "sum")
	fmt.println("Built add instruction: sum = a + b")

	// Build return
	llvm.LLVMBuildRet(builder, result)
	fmt.println("Built return instruction")

	// Verify module
	error_msg: cstring
	verify_result := llvm.LLVMVerifyModule(
		module,
		llvm.VerifierFailureAction.AbortProcessAction,
		&error_msg,
	)
	if verify_result != 0 {
		fmt.eprintln("Module verification failed:", error_msg)
		llvm.LLVMDisposeMessage(error_msg)
		llvm.LLVMDisposeModule(module)
		llvm.LLVMContextDispose(ctx)
		os.exit(1)
	}
	fmt.println("Module verified successfully!")

	// Print module to string
	module_str := llvm.LLVMPrintModuleToString(module)
	fmt.println("\n=== Generated LLVM IR ===")
	fmt.println(module_str)
	llvm.LLVMDisposeMessage(module_str)

	// Cleanup
	llvm.LLVMDisposeBuilder(builder)
	llvm.LLVMDisposeModule(module)

	fmt.println("\n=== Test PASSED ===")
	fmt.println("Linux LLVM-Odin binding is working correctly!")
}
