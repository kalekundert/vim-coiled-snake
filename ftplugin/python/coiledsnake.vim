if exists('b:vim_coiled_snake_loaded')
    finish
endif
let b:vim_coiled_snake_loaded = 1

" TODO:
" - Options to prevent folding at certain depths, fold sizes, parents?
" - Write docs

setlocal foldexpr=coiledsnake#FoldExpr(v:lnum)
setlocal foldtext=coiledsnake#FoldText()
setlocal foldmethod=expr

augroup CoiledSnake
    autocmd TextChanged,InsertLeave <buffer> call coiledsnake#ClearFolds()
augroup END

