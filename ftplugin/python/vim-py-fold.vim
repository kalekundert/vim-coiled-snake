if exists('b:loaded_vim_py_fold')
    finish
endif
let b:loaded_vim_py_fold = 1

setlocal foldexpr=FoldExpr(v:lnum)
setlocal foldtext=FoldTextCaller()
setlocal foldmethod=expr

augroup VimPyFold
    autocmd TextChanged,InsertLeave <buffer> call ClearFolds()
augroup END

