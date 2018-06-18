Coiled Snake: Python Folding for Vim
====================================
Coiled Snake is a vim plugin that provides automatic folding of python code. 
Its priorities are: (i) to make folds that are satisfyingly compact, (ii) to be 
attractive and unobtrusive, and (iii) to be robust to any kind of style or 
formatting.  Here's what it looks like in action:

<p><a href="https://asciinema.org/a/Oof5vJDm9gDOZO0N3KEJJt6PT?autoplay=1">
<img src="https://asciinema.org/a/Oof5vJDm9gDOZO0N3KEJJt6PT.png" width="500"/>
</a></p>

A couple features are worth drawing attention to:

- Classes, functions, docstrings, imports, and large data structures are all 
  automatically recognized and folded.
- The folds seek to hide as much unnecessary clutter as possible, including 
  blank lines between methods or classes, decorators, docstring quotes, etc.
- Each fold is summarized clearly and without visual clutter.  The summaries 
  can also present context-specific information, like whether a class or 
  function has been documented.
- The algorithms for automatically creating the folds and summarizing the folds 
  are independent from each other, so if you only like one you don't have to 
  use the other.

Installation
------------
Coiled Snake is compatible with both ``vim`` and ``neovim``, and can be 
installed using any of the plugin management tools out there.  I recommend 
also installing the [FastFold](https://github.com/Konfekt/FastFold) plugin, 
since it does a lot to make folding a more pleasant experience.

### pathogen

Clone this repository into your ``.vim/bundle`` directory:

    cd ~/.vim/bundle
    git clone git://github.com/kalekundert/vim-coiled-snake.git
    git clone git://github.com/Konfect/FastFold

### vim-plug

Put the following line(s) in the ``call plug#begin()`` section of your ``.vimrc`` 
file:

    Plug 'kalekundert/vim-coiled-snake'
    Plug 'Konfect/FastFold'

Usage
-----
Coiled Snake simply uses the standard folding commands.  See [``:help 
fold-commands``](https://neovim.io/doc/user/fold.html) if you're 
not familiar, but below the commands I use most frequently:

- ``zo``: Open a fold
- ``zc``: Close a fold
- ``zk``: Jump to the previous fold.
- ``zj``: Jump to the next fold.
- ``zR``: Open every fold.
- ``zM``: Close every fold.

You can prevent Coiled Snake from folding a line that it would otherwise by 
putting a ``#`` at the end of the line.  For example, the following function 
would not be folded:

    def not_worth_folding(): #
        return 42

Configuration
-------------
- ``g:coiled_snake_set_foldtext``
    
  If false, don't change the algorithm for labeling folds.

- ``g:coiled_snake_set_foldexpr``

  If false, don't change the algorithm for making folds.

- ``g:CoiledSnakeConfigureFold(fold)``

  This is a function that is called to customize how folds are made.  The 
  argument is a ``Fold`` object, which describes what kind of fold it is 
  (imports, function, class, docstring, etc.) and how it should be folded 
  (e.g. whether it should be folded at all, where it should start and end, 
  how trailing blank lines should be handled, etc.).  The purpose of the 
  function is to inspect this fold and to change any settings you'd like.
  
  The best way to illustrate how this works is with an example:

      function! g:CoiledSnakeConfigureFold(fold)

          " Don't fold nested classes.
          if a:fold.type == 'class'
              let a:fold.max_level = 1

          " Don't fold doubly nested functions, and include up to 2 
          " trailing blank lines in function folds.
          elseif a:fold.type == 'function'
              let a:fold.max_level = 2
              let a:fold.num_blanks_below = 2

          " Only fold imports if there are at least 5 of them.
          elseif a:fold.type == 'import'
              let a:fold.min_lines = 5
          endif

          " If the whole program is shorter than 50 lines, don't fold 
          " anything.
          if line('$') < 50
              let a:fold.ignore = 1
          endif
      endfunction

Contributing
------------
[Bug reports](https://github.com/kalekundert/vim-coiled-snake/issues) and [pull 
requests](https://github.com/kalekundert/vim-coiled-snake/pulls) are welcome.  I'm especially interested to hear 
about cases where the folding algorithm produces goofy results, since it's hard 
to encounter every corner case.
