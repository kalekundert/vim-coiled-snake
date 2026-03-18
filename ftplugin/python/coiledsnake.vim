call coiledsnake#LoadSettings()

if !exists('b:undo_ftplugin')
    let b:undo_ftplugin = ''
endif
let b:undo_ftplugin = 'setlocal foldmethod< foldexpr< foldtext<'
    \ . ' | autocmd! CoiledSnake TextChanged,InsertLeave <buffer>'
    \ . ' | unlet! b:coiled_snake_marks'
    \ . b:undo_ftplugin

if g:coiled_snake_set_foldtext
    call coiledsnake#EnableFoldText()
endif
if g:coiled_snake_set_foldexpr
    call coiledsnake#EnableFoldExpr()
endif

" vim: ts=4 sts=4 sw=4 fdm=marker et sr
