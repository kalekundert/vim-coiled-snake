if exists('b:vim_boa_fold_loaded')
    finish
endif
let b:vim_boa_fold_loaded = 1

" TODO:
" - Options to prevent folding at certain depths, fold sizes, parents?
" - Write docs

setlocal foldexpr=boa#FoldExpr(v:lnum)
setlocal foldtext=boa#FoldText()
setlocal foldmethod=expr

augroup VimBoaFold
    autocmd TextChanged,InsertLeave <buffer> call boa#ClearFolds()
augroup END

