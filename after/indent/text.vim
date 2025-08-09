if exists("b:did_indent")
    finish
endif

let b:did_indent = 1

setlocal indentexpr=TextIndent()

if exists("*TextIndent")
    finish
endif

function! TextIndent()
    let line_num = line(".")
    let prev_nonblank = prevnonblank(line_num - 1)
    let prev_nonblank_indent = indent(prev_nonblank)
    if prev_nonblank_indent <= 0
        return 0
    else
        return prev_nonblank_indent
    endif
endfunction
