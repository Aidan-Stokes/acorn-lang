package common

Error :: struct {
    message: string,
    line:    int,
    column:  int,
}

errors: [dynamic]Error

init_errors :: proc() {
    clear(&errors)
}

add_error :: proc(message: string, line: int, column: int) {
    append(&errors, Error{message = message, line = line, column = column})
}

has_errors :: proc() -> bool {
    return len(errors) > 0
}

get_errors :: proc() -> []Error {
    return errors[:]
}
