Coiled Snake: Python Folding for Vim
====================================
Coiled Snake is a vim plugin that provides automatic folding of python code. 
Its priorities are: (i) to make folds that are satisfyingly compact, (ii) to be 
attractive and unobtrusive, (iii) to be robust to any kind of style or 
formatting, and (iv) to be highly configurable.  Here's what it looks like in 
action:

<p><a href="https://asciinema.org/a/Oof5vJDm9gDOZO0N3KEJJt6PT?autoplay=1">
<img src="https://asciinema.org/a/Oof5vJDm9gDOZO0N3KEJJt6PT.png" width="500"/>
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
Coiled Snake is compatible with both ``vim`` and ``neovim``, and can be 
installed using any of the plugin management tools out there.  I recommend 
also installing the [FastFold](https://github.com/Konfekt/FastFold) plugin, 
since I find that it makes folding more responsive and less finicky, but it's 
not required.

### [pathogen](https://github.com/tpope/vim-pathogen)

Clone this repository into your ``.vim/bundle`` directory:

    cd ~/.vim/bundle
    git clone git://github.com/kalekundert/vim-coiled-snake.git
    git clone git://github.com/Konfect/FastFold

### [vim-plug](https://github.com/junegunn/vim-plug)

Put the following line(s) in the ``call plug#begin()`` section of your ``.vimrc`` 
file:

    Plug 'kalekundert/vim-coiled-snake'
    Plug 'Konfect/FastFold'

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

- ``g:coiled_snake_set_foldtext``
    
  If false, don't change the algorithm for labeling folds.

- ``g:coiled_snake_set_foldexpr``

  If false, don't change the algorithm for making folds.

- ``g:CoiledSnakeConfigureFold(fold)``

  This is a function that is called to customize how folds are made.  The 
  argument is a ``Fold`` object, which describes the fold (e.g. what line did 
  it start on, how indented is it, etc.) and how it should behave  
  (e.g. whether it should be folded at all, where it should start and end, 
  how trailing blank lines should be handled, etc.).  The purpose of this 
  function is to inspect the given fold and to change any settings you'd like.
  
  The best way to illustrate how this works is with an example:

      function! g:CoiledSnakeConfigureFold(fold)
      
          " Don't fold nested classes.
          if a:fold.type == 'class'
              let a:fold.max_level = 1
      
          " Don't fold nested functions, but do fold methods (i.e. functions 
          " nested inside classes).
          elseif a:fold.type == 'function'
              let a:fold.max_level = 1
              if get(a:fold.parent, 'type') == 'class'
                  let a:fold.max_level = 2
              endif
      
          " Only fold imports if there are at least 3 of them.
          elseif a:fold.type == 'import'
              let a:fold.min_lines = 3
          endif
      
          " If the whole program is shorter than 30 lines, don't fold 
          " anything.
          if line('$') < 30
              let a:fold.ignore = 1
          endif
      
      endfunction

    By default, import blocks will only be folded if they are 4 lines or 
    longer, class blocks will collapse up to 2 trailing blank lines, function 
    blocks will collapse up to 1 trailing blank line, and data structure blocks 
    (e.g. literal lists, dicts, sets) will only be folded if they are 
    unindented and longer than 6 lines.

  ``Fold`` object attributes:

  - ``type`` (str, read-only): The kind of lines being folded.  The following 
    values are possible: ``'import'``, ``'decorator'``, ``'class'``, 
    ``'function'``, ``'struct'``, ``'docstring'``.

  - ``parent`` (Fold, read-only): The fold containing this one, or ``{}`` if 
    this is a top level fold.

  - ``lnum`` (int, read-only): The line number (1-indexed) of the first line in 
    the fold.

  - ``level`` (int, read-only): How nested the fold is, where 1 indicates 
    no nesting.  This is based on the indent of the first line in the fold.

  - ``min_lines`` (int): If the fold would include fewer lines than this, it 
    will not be created. 

  - ``max_indent`` (int): If the fold would be more indented than this, it will 
    not be created.

  - ``max_level`` (int): If the fold would have a higher level than this, it 
    will not be created.  This is subtly different than ``max_indent``.  For 
    example, consider a function defined in a for-loop.  Because the loop 
    isn't folded, the level isn't affected while the indent is.

  - ``ignore`` (bool): If true, the fold will not be created.

  - ``num_blanks_below`` (int): The number of trailing blank lines to include 
    in the fold.  Only the ``'decorator'``, ``'class'``, and ``'function'`` 
    types of fold respect this option.

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
    end on ``inside_line``.  the ``num_lines_below`` option 

  ``Line`` object attributes:

  - ``lnum`` (int, read-only): The line number (1-indexed) of the line.

  - ``text`` (str, read-only): The text contained by the line.

  - ``indent`` (int, read-only): The number of leading spaces on the line.

  - ``is_code`` (bool, read-only): ``1`` if the line is considered "code", 
    ``0`` otherwise.  A line is not considered "code" if it is blank or part of 
    a multiline string.

  - ``is_blank`` (bool, read-only): ``1`` if the line contains only whitespace, 
    ``0`` otherwise.

Contributing
------------
[Bug reports](https://github.com/kalekundert/vim-coiled-snake/issues) and [pull 
requests](https://github.com/kalekundert/vim-coiled-snake/pulls) are welcome.  I'm especially interested to hear 
about cases where the folding algorithm produces goofy results, since it's hard 
to encounter every corner case.
