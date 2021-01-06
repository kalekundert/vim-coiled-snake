Coiled Snake: Python Folding for Vim
====================================
Coiled Snake is a vim plugin that provides automatic folding of python code. 
Its priorities are: (i) to make folds that are satisfyingly compact, (ii) to be 
attractive and unobtrusive, (iii) to be robust to any kind of style or 
formatting, and (iv) to be highly configurable.  Here's what it looks like in 
action:

<p><a href="https://asciinema.org/a/234369?autoplay=1">
<img src="https://asciinema.org/a/234369.png" width="500"/>
</a></p>

A couple features are worth drawing attention to:

- Classes, functions, docstrings, imports, and large data structures are all 
  automatically recognized and folded.
- The folds seek to hide as much unnecessary clutter as possible, e.g. 
  blank lines between methods or classes, docstring quotes, decorator lines, 
  etc.
- Each fold is labeled clearly and without visual clutter.  The labels 
  can also present context-specific information, like whether a class or 
  function has been documented.
- The algorithms for automatically creating the folds and summarizing the folds 
  are independent from each other, so if you only like one you don't have to 
  use the other.

Installation
------------
Coiled Snake is compatible with both ``vim>=7.4`` and ``neovim``, and can be 
installed using any of the plugin management tools out there.  I recommend 
also installing the [FastFold](https://github.com/Konfekt/FastFold) plugin, 
since I find that it makes folding more responsive and less finicky, but it's 
not required.

### [pathogen](https://github.com/tpope/vim-pathogen)

Clone this repository into your ``.vim/bundle`` directory:

    cd ~/.vim/bundle
    git clone git://github.com/kalekundert/vim-coiled-snake.git
    git clone git://github.com/Konfekt/FastFold

### [vim-plug](https://github.com/junegunn/vim-plug)

Put the following line(s) in the ``call plug#begin()`` section of your ``.vimrc`` 
file:

    Plug 'kalekundert/vim-coiled-snake'
    Plug 'Konfekt/FastFold'

### [Vim8 native plugins](https://vimhelp.org/repeat.txt.html#packages)

Clone the repository into ``.vim/pack/*/start``:

    mkdir -p ~/.vim/pack/git-plugins/start
    cd ~/.vim/pack/git-plugins/start
    git clone git://github.com/kalekundert/vim-coiled-snake.git

Note that you can name the directories in ``.vim/pack/`` whatever you like, so 
the ``git-plugins`` name in the snippet above is just an example.  Also be sure 
to enable the following option in your ``.vimrc`` file::

    filetype plugin indent on

Usage
-----
Coiled Snake works with all the standard folding commands.  See [``:help 
fold-commands``](https://neovim.io/doc/user/fold.html) if you're 
not familiar, but below are the commands I use most frequently:

- ``zo``: Open a fold
- ``zc``: Close a fold
- ``zk``: Jump to the previous fold.
- ``zj``: Jump to the next fold.
- ``zR``: Open every fold.
- ``zM``: Close every fold.

You can prevent Coiled Snake from folding a line that it otherwise would by 
putting a ``#`` at the end of said line.  For example, the following function 
would not be folded:

    def not_worth_folding(): #
        return 42

Configuration
-------------
No configuration is necessary, but the following options are available:

- ``g:coiled_snake_set_foldtext`` (default: ``1``)
    
  If false, don't load the algorithm for labeling folds.

- ``g:coiled_snake_set_foldexpr`` (default: ``1``)

  If false, don't load the algorithm for making folds.

- ``g:coiled_snake_foldtext_flags`` (default: ``['doc', 'static']``)

  A list of the annotations (if any) you want to appear in the fold summaries. 
  The following values are understood:
  - ``'doc'``: Documented classes and functions.
  - ``'static'``: Static and class methods.

- ``g:coiled_snake_explicit_sign_width`` (default: ``0``)

  Explicitly set the width of the sign column used by plugins such as 
  [vim-gitgutter](https://github.com/airblade/vim-gitgutter).  This width is 
  determined automatically in most cases, but this setting may be useful if the 
  automatic determination fails.

- ``g:CoiledSnakeConfigureFold(fold)``

  This function is called on each automatically-identified fold to customize 
  how it should behave. The argument is a ``Fold`` object, which describes all 
  aspects of the fold in question (e.g. where does it start and end, is it 
  nested in another fold, should it be folded at all, how should trailing blank 
  lines be handled, etc).  By interacting with this object, you can do a lot to 
  control how the code is folded.
  
  The best way to illustrate this is with an example:

      function! g:CoiledSnakeConfigureFold(fold)
      
          " Don't fold nested classes.
          if a:fold.type == 'class'
              let a:fold.max_level = 1
      
          " Don't fold nested functions, but do fold methods (i.e. functions 
          " nested inside a class).
          elseif a:fold.type == 'function'
              let a:fold.max_level = 1
              if get(a:fold.parent, 'type', '') == 'class'
                  let a:fold.max_level = 2
              endif
      
          " Only fold imports if there are 3 or more of them.
          elseif a:fold.type == 'import'
              let a:fold.min_lines = 3
          endif
      
          " Don't fold anything if the whole program is shorter than 30 lines.
          if line('$') < 30
              let a:fold.ignore = 1
          endif
      
      endfunction

    By default, import blocks are only folded if they are 4 lines or longer, 
    class blocks collapse up to 2 trailing blank lines, function blocks 
    collapse up to 1 trailing blank line, and data structure blocks (e.g. 
    literal lists, dicts, sets) are only folded if they are unindented and 
    longer than 6 lines.

  ``Fold`` object attributes:

  - ``type`` (str, read-only): The kind of lines being folded.  The following 
    values are possible: ``'import'``, ``'decorator'``, ``'class'``, 
    ``'function'``, ``'struct'``, ``'doc'``.

  - ``parent`` (Fold, read-only): The fold containing this one, or ``{}`` if 
    this is a top level fold.

  - ``lnum`` (int, read-only): The line number (1-indexed) of the first line in 
    the fold.

  - ``indent`` (int, read-only): The indent on the first line of the fold.

  - ``level`` (int, read-only): How nested the fold is, where 1 indicates 
    no nesting.  This is based on the indent of the first line in the fold.

  - ``min_lines`` (int): If the fold would include fewer lines than this, it 
    will not be created. 

  - ``max_indent`` (int): If the fold would be more indented than this, it will 
    not be created.  This option is ignored if it's less than 0.

  - ``max_level`` (int): If the fold would have a higher level than this, it 
    will not be created.  This option is ignored if it's less than 0.  Note 
    that this is subtly different than ``max_indent``.  For example, consider a 
    function defined in a for-loop.  Because the loop isn't folded, the level 
    isn't affected while the indent is.

  - ``ignore`` (bool): If true, the fold will not be created.

  - ``num_blanks_below`` (int): The number of trailing blank lines to include 
    in the fold, if the next fold follows immediately after and is of the same 
    type and level as this one.  This is useful for collapsing the blank space 
    between classes and methods.

  - ``NumLines()`` (int, read-only): A method that returns the minimum number 
    of lines that will be included in the fold, not counting any trailing blank 
    lines that may be collapsed.  

  - ``opening_line`` (Line, read-only): A ``Line`` object (see below) 
    representing the first line of the fold.

  - ``inside_line`` (Line, read-only): A ``Line`` object (see below) 
    representing the last line that should be included in the fold.  The fold 
    may actually end on a subsequent line, e.g. to collapse trailing blank 
    lines. 

  - ``outside_line`` (Line, read-only): A ``Line`` object (see below) 
    representing the first line after the fold that should *not* be included in 
    it.  The lines between ``inside_line`` and ``outside_line`` are typically 
    blank, and may be added to the fold depending on the value of the 
    ``num_lines_below`` attribute.  May be ``{}``, in which case the fold will 
    end on ``inside_line``.

  ``Line`` object attributes:

  - ``lnum`` (int, read-only): The line number (1-indexed) of the line.

  - ``text`` (str, read-only): The text contained by the line.

  - ``code`` (str, read-only): A modified version of `Line.text` without 
    strings or comments.

  - ``indent`` (int, read-only): The number of leading spaces on the line.

  - ``ignore_indent`` (bool, read-only): If true, the indentation on this line 
    is not meaningful to python.  This could mean that the line is a comment, 
    part of a multiline string, wrapped in parentheses, etc.

  - ``paren_level`` (int, read-only): The number of parentheses, brackets, and 
    braces surrounding this line.

  - ``is_blank`` (bool, read-only): ``1`` if the line contains only whitespace, 
    ``0`` otherwise.

  - ``is_continuation`` (bool, read-only): If true, this line is part of an 
    expression that began on a previous line.


Troubleshooting
---------------
- If docstrings don't seems to be folding properly, the problem may be that vim 
  is running in vi-compatibility mode.  Coiled Snake does not work in this 
  mode, and (for various reasons) docstrings are usually the first symptom.  
  The solution is to either disable comptibility mode (`:set nocompatible`) or 
  to specifically allow line continuation in vim scripts (`:set cpoptions-=C`).

- If anything else seems broken, it may be that the code is crashing in the 
  middle of making the folds.  Vim hides errors that occur during this process, 
  so you might never know that the code is crashing.  To see these errors, run 
  `:call coiledsnake#DebugFolds()` (if the problem is with the folds 
  themselves) or `:call coiledsnake#DebugText()` (if the problem is with the 
  fold labels).  If there are any errors, include that information in a [bug 
  report](https://github.com/kalekundert/vim-coiled-snake/issues).
  
Contributing
------------
[Bug reports](https://github.com/kalekundert/vim-coiled-snake/issues) and [pull 
requests](https://github.com/kalekundert/vim-coiled-snake/pulls) are welcome.  I'm especially interested to hear 
about cases where the folding algorithm produces goofy results, since it's hard 
to encounter every corner case.
