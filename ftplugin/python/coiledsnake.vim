if exists('b:coiled_snake_should_fold')
    finish
endif
let b:coiled_snake_should_fold = 1

if !exists('b:undo_ftplugin')
    let b:undo_ftplugin = ''
endif
let b:undo_ftplugin = 'unlet b:coiled_snake_should_fold' . b:undo_ftplugin

" vim: ts=4 sts=4 sw=4 fdm=marker et sr
