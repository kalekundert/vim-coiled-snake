Coiled Snake
============
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
Coiled Snake simply uses the standard folding commands.  If you're not 
familiar, here's a brief introduction:

- ``zo``: Open a fold
- ``zc``: Close a fold
- ``zk``: Jump to the previous fold.
- ``zj``: Jump to the next fold.
- ``zR``: Open every fold.
- ``zM``: Close every fold.

See [``:help folding``](https://neovim.io/doc/user/fold.html) for more 
information.

Contributing
------------
[Bug reports](https://github.com/kalekundert/vim-coiled-snake/issues) and [pull 
requests](https://github.com/kalekundert/vim-coiled-snake/pulls) are welcome.  I'm especially interested to hear 
about cases where the folding algorithm produces goofy results, since it's hard 
to encounter every corner case.
