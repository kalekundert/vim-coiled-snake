function! s:OnFileType() " {{{1
    if ! get(b:, 'coiled_snake_bufenter', 0)
        " Don't do anything before the buffer has been loaded.
        return
    elseif &filetype != 'python' || &diff
        " Don't do anything if this isn't a python file.
        return
    endif

    call coiledsnake#LoadSettings()

    if g:coiled_snake_set_foldtext
        call coiledsnake#EnableFoldText()
    endif
    if g:coiled_snake_set_foldexpr
        call coiledsnake#EnableFoldExpr()
    endif
endfunction

function! s:OnBufEnter() " {{{1
    let b:coiled_snake_bufenter = 1
    call s:OnFileType()
endfunction

function! s:OnBufLeave() " {{{1
    call coiledsnake#ResetFoldText()
    call coiledsnake#ResetFoldExpr()
endfunction

augroup CoiledSnake " {{{1
    autocmd FileType * call s:OnFileType()
    autocmd BufEnter * call s:OnBufEnter()
    autocmd BufLeave * call s:OnBufLeave()
augroup END

" vim: ts=4 sts=4 sw=4 fdm=marker et sr
