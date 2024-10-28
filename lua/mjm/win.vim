"
" Highlight current window
"
func! s:focusable_wins() abort
    return filter(nvim_tabpage_list_wins(0), {k,v-> !!nvim_win_get_config(v).focusable})
endf
augroup config_curwin_border
    autocmd!
    highlight CursorLineNC cterm=underdashed gui=underdashed ctermfg=gray guisp=NvimLightGrey4 ctermbg=NONE guibg=NONE
    highlight link WinBorder Statusline

    " Dim non-current cursorline.
    autocmd VimEnter,WinEnter,TabEnter,BufEnter * setlocal winhighlight-=CursorLine:CursorLineNC

    " Highlight curwin WinSeparator/SignColumn for "border" effect.
    let s:winborder_hl = 'WinSeparator:WinBorder,SignColumn:WinBorder'
    autocmd WinLeave * exe 'setlocal winhighlight+=CursorLine:CursorLineNC winhighlight-='..s:winborder_hl
    autocmd WinEnter * exe 'setlocal winhighlight+='..s:winborder_hl
    " Disable effect if there is only 1 window.
    autocmd WinResized * if 1 == len(s:focusable_wins()) | exe 'setlocal winhighlight-='..s:winborder_hl | endif
augroup END
