if exists('b:vim_coiled_snake_loaded')
    finish
endif
let b:vim_coiled_snake_loaded = 1

" TODO:
" - Options to prevent folding at certain depths, fold sizes, parents?
" - Write docs

call coiledsnake#loadSettings()

if g:coiled_snake_set_foldtext
    call coiledsnake#EnableFoldText()
endif
if g:coiled_snake_set_foldexpr
    call coiledsnake#EnableFoldExpr()
endif

