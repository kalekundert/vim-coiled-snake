function! s:window_entered()
    if &filetype != 'python' || &diff
        " Should not fold
        return
    endif
    let w:coiled_snake_enabled = 1
    call coiledsnake#loadSettings()
    call coiledsnake#EnableFoldText()
    call coiledsnake#EnableFoldExpr()
endfun

function! s:window_leave()
    if get(w:,'coiled_snake_enabled',0)
        call coiledsnake#ResetFoldText()
        call coiledsnake#ResetFoldExpr()
    endif
endfun

augroup CoiledSnake
    autocmd BufEnter,FileType * call s:window_entered()
    autocmd BufLeave          * call s:window_leave()
augroup END

" vim: ts=4 sts=4 sw=4 fdm=marker et sr
