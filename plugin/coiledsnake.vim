function! s:setFolds() " {{{1
    let w:coiled_snake_folded = 0

    if ! (exists('b:coiled_snake_should_fold') && b:coiled_snake_should_fold)
        " not python, reset folds if we had set them earlier
        call s:resetFolds()
        return
    endif
    if ! (&foldmethod ==# &g:foldmethod
                \&& &foldexpr ==# &g:foldexpr
                \&& &foldmethod ==# &g:foldmethod)
        " something is not at default value. not safe to fold.
        return
    endif

    call coiledsnake#LoadSettings()

    if g:coiled_snake_set_foldtext
        call coiledsnake#EnableFoldText()
    endif
    if g:coiled_snake_set_foldexpr
        call coiledsnake#EnableFoldExpr()
    endif

    let w:coiled_snake_folded = 1
endfunction

function! s:resetFolds() " {{{1
    if (exists('w:coiled_snake_folded') && w:coiled_snake_folded)
        call coiledsnake#ResetFoldText()
        call coiledsnake#ResetFoldExpr()
    endif
endfunction

augroup CoiledSnake " {{{1
    autocmd!
    " BufWinEnter to handle Buffers entering windows
    " WinNew to handle :split, because it doesn't trigger BufWinEnter
    autocmd BufWinEnter,WinNew * call s:setFolds()
augroup END
" }}}1

" vim: ts=4 sts=4 sw=4 fdm=marker et sr
