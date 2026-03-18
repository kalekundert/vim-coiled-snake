# vim-coiled-snake Tests

## Running the tests

Run the automated test suite with `run_tests.py`:

```sh
# Run all tests with both vim and nvim
./run_tests.py

# Run with a specific editor only
./run_tests.py --vim
./run_tests.py --nvim

# Run specific test files
./run_tests.py examples/class.py
./run_tests.py examples/syntax/*.py
```

Each test file (`.py`) has a companion `.marks` file containing the expected
`coiledsnake#FoldExpr()` output, one mark per line (e.g. `>1`, `=`, `<1`).

### Adding a new test

1. Create a `.py` input file in the appropriate directory.
2. Run `run_tests.py`.  It will report the test as NEW and print a shell
   command to create the `.marks` file.
3. Review the actual marks, then run the printed command to save them.

### Updating expected marks

Delete the `.marks` file and rerun `run_tests.py` to regenerate it, or edit
it manually.

### Custom vimrc per test

Place a `.vimrc` companion file next to the `.py` file (e.g.
`issues/test_7.vimrc` for `issues/test_7.py`). The following options must be 
set in order for `vim-coiled-snake` to function:

```
" This tells vim to load the `vim-coiled-snake` source directory as a plugin.  
" Note that you may need to adjust the path depending on where your vimrc file
" is located.
let s:dir = expand('<sfile>:p:h')
execute 'set runtimepath^=' .. s:dir .. '/..'

" Allow vim to activate language-specific plugins, like `vim-coiled-snake`.
filetype plugin indent on

" Disable a vi-compatibility option that breaks `vim-coiled-snake`.
set cpoptions-=C
```

An easy way to set all of these options is to source `tests/vimrc`, which is 
the default `.vimrc` file used by tests that don't specify their own.

## Interactive visual tests

For manual fold inspection in a running Vim/Neovim session:

```sh
tests/run_vim.sh examples/class.py
tests/run_nvim.sh examples/class.py
```

Debug commands (run inside Vim on a Python buffer):

```vim
:call coiledsnake#DebugFolds()
:call coiledsnake#DebugLines()
:call coiledsnake#DebugMarks()
:call coiledsnake#DebugText()
```
