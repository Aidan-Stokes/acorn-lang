package common

import "core:mem"

current_allocator: mem.Allocator

// Global error reporter
global_reporter: Error_Reporter

init :: proc() {
    init_reporter(&global_reporter)
}

destroy :: proc() {
    destroy_reporter(&global_reporter)
}

set_allocator :: proc(alloc: mem.Allocator) {
    current_allocator = alloc
}

get_allocator :: proc() -> mem.Allocator {
    if current_allocator.data == nil {
        return context.allocator
    }
    return current_allocator
}

_get_allocator :: #force_inline proc(allocator: mem.Allocator) -> mem.Allocator {
    if allocator.data == nil {
        return get_allocator()
    }
    return allocator
}
