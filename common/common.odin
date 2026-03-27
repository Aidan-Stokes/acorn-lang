package common

import "core:mem"

current_allocator: mem.Allocator

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
