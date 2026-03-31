; ModuleID = 'acorn_module'
source_filename = "acorn_module"

@PI = constant double 3.141590e+00
@E = constant double 2.718280e+00
@TAU = constant double 6.283180e+00

define i32 @print_int(i32 %0) {
entry:
  %x = alloca i32, align 4
  store i32 %0, ptr %x, align 4
  ret i32 0
}

define i32 @print_float(i32 %0) {
entry:
  %x = alloca i32, align 4
  store i32 %0, ptr %x, align 4
  ret i32 0
}

define i32 @print_string(i32 %0) {
entry:
  %s = alloca i32, align 4
  store i32 %0, ptr %s, align 4
  ret i32 0
}

define i32 @println(i32 %0) {
entry:
  %x = alloca i32, align 4
  store i32 %0, ptr %x, align 4
  ret i32 0
}

define i32 @println_string(i32 %0) {
entry:
  %s = alloca i32, align 4
  store i32 %0, ptr %s, align 4
  ret i32 0
}

define i32 @main() {
entry:
  %const_tmp = alloca double, align 8
  store double 3.141590e+00, ptr %const_tmp, align 8
  %PI = load double, ptr %const_tmp, align 8
  %x = alloca i32, align 4
  %ftoi = fptosi double %PI to i32
  store i32 %ftoi, ptr %x, align 4
  %x1 = load i32, ptr %x, align 4
  %calltmp = call i32 @println(i32 %x1)
  ret i32 0
}
