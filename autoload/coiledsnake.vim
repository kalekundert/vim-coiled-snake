" Patterns {{{1
let s:blank_pattern = '^\s*$'
let s:comment_pattern = '^\s*#'
let s:import_pattern = '^\(import\|from\)'
let s:import_continue_pattern = join([s:import_pattern, s:blank_pattern, s:comment_pattern], '\|')
let s:class_pattern = '^\s*class\s'
let s:function_pattern = '^\s*\(\(async\s\+\)\?def\s\|if __name__\s==\)'
let s:block_pattern = join([s:class_pattern, s:function_pattern], '\|')
let s:decorator_pattern = '^\s*@'
let s:string_start_pattern = '[bBfFrRuU]\{0,2}\(''''''\|"""\)\\\?'
let s:string_start_end_pattern = s:string_start_pattern . '.*\1'
let s:docstring_pattern = '^\s*' . s:string_start_pattern
let s:data_struct_pattern = '^\s*[a-zA-Z0-9_.]\+ = \({\|\[\|(\|'.s:string_start_pattern.'\)\s*$'
let s:data_struct_close_pattern = '^\s*\(}\|\]\|)\|''''''\|"""\)$'
let s:manual_open_pattern = '^\s*##'
let s:manual_ignore_pattern = '#$'
" }}}1

function! coiledsnake#FoldExpr(lnum) abort "{{{1
    if !exists('b:marks')
        let b:marks = coiledsnake#RefreshFolds()
    endif
    return get(b:marks, a:lnum, '=')
endfunction

function! coiledsnake#FoldText() abort "{{{1
    return coiledsnake#FormatText(v:foldstart, v:foldend)
endfunction

function! coiledsnake#ClearFolds() abort "{{{1
    if exists('b:marks')
        unlet b:marks
    endif
endfunction

function! coiledsnake#RefreshFolds() abort "{{{1
    let b:marks = {}
    let lines = s:LinesFromBuffer()
    let folds = s:FoldsFromLines(lines)

    " Cache where each fold should open and close.
    for lnum in sort(keys(folds), 's:LowToHigh')
        let l:fold = folds[lnum]

        " Open a fold at the appropriate level on this line.
        let b:marks[l:fold.lnum] = '>' . l:fold.level

        " If no inside line was found, the fold reaches the end of the file and 
        " doesn't need to be closed.
        if l:fold.inside_line == {}
            continue

        " If this fold and the next are the same type and separated only by 
        " blank lines, allow a certain number of those lines to be included in 
        " the fold.
        elseif l:fold.type == get(l:fold.next_fold, 'type', '')
                    \ && l:fold.level == get(l:fold.next_fold, 'level')
            let closing_lnum = min([
                    \ l:fold.inside_line.lnum + l:fold.num_blanks_below,
                    \ l:fold.outside_line.lnum])

        " If only an inside line was specified, close the fold exactly on that 
        " line.
        else 
            let closing_lnum = l:fold.inside_line.lnum
        endif

        " Indicate that the fold should be closed, but don't overwrite any 
        " previous entries.  Due to the way the code is organized, any previous 
        " entries will be higher level folds, and we want those to take 
        " precedence.
        if ! has_key(b:marks, closing_lnum)
            let b:marks[closing_lnum] = '<' . l:fold.level
        endif

        " Ignore folds that end up opening and closing on the same line.
        if closing_lnum == l:fold.lnum
            unlet b:marks[closing_lnum]
        endif

    endfor

    return b:marks
endfunction

function! coiledsnake#FormatText(foldstart, foldend) abort " {{{1
    " Find the line that should be used to represent the fold.  This is usually 
    " the first line, but docstrings and decorators are handled specially.

    let focus = {}
    let focus.text = getline(a:foldstart)
    let focus.offset = 0

    if focus.text =~# s:decorator_pattern
        call s:FindDecoratorTitle(focus, a:foldstart, a:foldend)
    elseif focus.text =~# s:docstring_pattern
        call s:FindDocstringTitle(focus, a:foldstart, a:foldend)
    endif

    " Break the line into two parts: a title and a set of flags.  The title 
    " will be left-justified, while the flags will be concatenated together and 
    " right-justified.

    function! AddBuiltinFlag(flags, flag, condition)
        if a:condition && index(g:coiled_snake_foldtext_flags, a:flag) >= 0
            call add(a:flags, a:flag)
        endif
    endfunction

    if focus.text =~# s:block_pattern
        let fields = split(focus.text, '#')
        let next_line = getline(a:foldstart + focus.offset + 1)

        " Flags are taken to be parenthetical phrases found within an inline
        " comment.  Line that don't have an inline comment can be trivially 
        " processed, so this case is handled specially.

        if len(fields) == 1
            let title = focus.text
            let flags = []
        else
            let title = fields[0]
            let flags = matchlist(fields[1], '(\([^)]\+\))')
            let flags = filter(flags[1:], 'v:val != ""')
        endif

        call AddBuiltinFlag(flags, "doc", next_line =~# s:docstring_pattern)
        call AddBuiltinFlag(flags, "static", get(focus, 'is_static'))

    else
        let title = focus.text
        let flags = []
    endif

    " Format a succinct fold message.  The title is stripped of whitespace and 
    " truncated, if it is too long to fit on the screen.  The total number of 
    " folded lines are added as an extra flag, and all the flags are wrapped in 
    " parenthesis.

    let flags = add(flags, 1 + a:foldend - a:foldstart)
    let status = '(' . join(flags, ') (') . ')'

    let cutoff = s:BufferWidth() - strlen(status)
    let title = substitute(title, '^\(.\{-}\)\s*$', '\1', '')
    
    if strlen(title) >= cutoff
        let title = title[0:cutoff - 4] . '...'
        let padding = ''
    else
        let padding = cutoff - strlen(title) - 1
        let padding = ' ' . repeat(' ', padding)
    endif

    return title . padding . status

endfunction

function! coiledsnake#loadSettings() abort "{{{1
    call s:SetIfUndef('g:coiled_snake_set_foldexpr', 1)
    call s:SetIfUndef('g:coiled_snake_set_foldtext', 1)
    call s:SetIfUndef('g:coiled_snake_foldtext_flags', ['doc', 'static'])
endfunction

function! coiledsnake#EnableFoldText() abort "{{{1
    setlocal foldtext=coiledsnake#FoldText()
endfunction

function! coiledsnake#EnableFoldExpr() abort "{{{1
    setlocal foldexpr=coiledsnake#FoldExpr(v:lnum)
    setlocal foldmethod=expr

    augroup CoiledSnake
        autocmd TextChanged,InsertLeave <buffer> call coiledsnake#ClearFolds()
    augroup END
endfunction

function! coiledsnake#DebugLines() abort "{{{1
    let lines = s:LinesFromBuffer()

    if type(lines) != type([])
        echo "Lines is not a list:"
        echo lines
        return
    endif

    echo "#   Code? Blank? Indent Text"
    for lnum in range(0, len(lines)-1)
        let line = lines[lnum]
        echo printf("%-3s %5s %6s %6s %s",
                    \ get(line, 'lnum', '???'),
                    \ get(line, 'is_code', '?'),
                    \ get(line, 'is_blank', '?'),
                    \ get(line, 'indent', '?'),
                    \ get(line, 'text', '???'))
    endfor
endfunction

function! coiledsnake#DebugFolds() abort "{{{1
    let lines = s:LinesFromBuffer()
    let folds = s:FoldsFromLines(lines)

    echo "  # In Out Type      Parent    Lvl Ig N? >? Text"
    for lnum in sort(keys(folds), 's:LowToHigh')
        let fold = folds[lnum]
        echo printf("%3s %2s %3s %-9.9s %-9.9s %3s %2s %2s %2s %s",
                    \ get(l:fold, 'lnum', '???'),
                    \ get(l:fold.inside_line, 'lnum', '??'),
                    \ get(l:fold.outside_line, 'lnum', '??'),
                    \ get(l:fold, 'type', '???'),
                    \ get(l:fold.parent, 'type', '???'),
                    \ get(l:fold, 'level', '?'),
                    \ get(l:fold, 'ignore', '?'),
                    \ get(l:fold, 'min_lines', '?'),
                    \ get(l:fold, 'max_level', '?'),
                    \ get(l:fold.opening_line, 'text', '???'))
    endfor
endfunction

function! coiledsnake#DebugMarks() abort "{{{1
    echo "#    Fold  Line"
    for lnum in range(1, line('$'))
        echo printf("%-3s  %4s  %s",
                    \ lnum,
                    \ coiledsnake#FoldExpr(lnum),
                    \ getline(lnum))
    endfor
endfunction

function! coiledsnake#DebugText() abort "{{{1
    echo "#    Line"
    for lnum in range(1, line('$'))
        echo coiledsnake#FormatText(lnum, lnum+1)
    endfor
endfunction

" }}}1

function! s:SetIfUndef(name, value) abort " {{{1
    if ! exists(a:name)
        let {a:name} = a:value
    endif
endfunction

function! s:LinesFromBuffer() abort "{{{1
    let lines = []
    let state = {'lines': lines}

    for lnum in range(1, line('$'))
        let line = s:InitLine(lnum, state)
        call add(lines, line)
    endfor

    return lines
endfunction

function! s:FoldsFromLines(lines) abort "{{{1
    let candidate_folds = {}
    let folds = {}
    let parents = {}
    let prev_fold = {}
    let prev_fold_by_level = {}

    " Create a data structure for each possible fold.
    for line in a:lines
        let l:fold = s:InitFold(line)
        if l:fold.type != ""
            let candidate_folds[l:fold.lnum] = l:fold
        endif
    endfor

    " Remove folds that don't meet certain criteria (e.g. number of lines, 
    " level of indentation, etc.) or have been ignored for some reason (e.g. in 
    " response to the user, or in the case of decorator and import fold, to 
    " avoid overlaps).
    for lnum in sort(keys(candidate_folds), 's:LowToHigh')
        let l:fold = candidate_folds[lnum]

        if l:fold.ignore
            continue
        endif

        " Figure out (roughly) where to close each fold.  This has to be done 
        " after all the folds have been loaded, so that earlier folds can 
        " supercede later ones.
        call l:fold.FindClosingInfo(a:lines, candidate_folds)

        " Note which lines are included in this fold, so that folds can be 
        " nested correctly.  Initially the nesting was based on indentation, 
        " but this led to fold levels getting skipped, e.g. if you define a 
        " function in a for-loop.
        let l:fold.parent = get(parents, l:fold.lnum, {})
        let l:fold.level = get(l:fold.parent, 'level', 0) + 1
        for lnum in range(l:fold.lnum + 1, l:fold.InsideLnumOrEOF())
            let parents[lnum] = l:fold
        endfor

        " Give the user a chance to configure the fold, e.g. set the max size 
        " or level, decide to ignore it for any reason, etc.
        if exists('*g:CoiledSnakeConfigureFold')
            call g:CoiledSnakeConfigureFold(l:fold)
        endif

        " Duplicate check, in case the `ignore` flag was set by 
        " `g:CoiledSnakeConfigureFold`.
        if l:fold.ignore
            continue
        endif

        if l:fold.NumLines() < l:fold.min_lines
            continue
        endif

        if l:fold.max_indent >= 0 && l:fold.opening_line.indent > l:fold.max_indent
            continue
        endif

        if l:fold.max_level >= 0 && l:fold.level > l:fold.max_level
            continue
        endif

        let folds[l:fold.lnum] = l:fold
    endfor

    " Make note of consecutive folds.  Blank lines may be collapsed bweteen 
    " consecutive folds of the same type.
    for lnum in sort(keys(folds), 's:LowToHigh')
        let l:fold = folds[lnum]
        let l:fold.next_fold = get(
                    \ folds,
                    \ get(l:fold.outside_line, 'lnum'),
                    \ {})
    endfor

    return folds
endfunction

function! s:InitLine(lnum, state) abort "{{{1
    let line = {}
    let line.lnum = a:lnum
    let line.text = getline(a:lnum)
    let line.indent = indent(a:lnum)
    let line.is_code = 1
    let line.is_blank = 0

    " Work out which lines are in comments or multiline strings and mark them 
    " as being 'not code'.  These need to be (largely) ignored by the folding 
    " machinery, since they could contain anything but shouldn't affect the 
    " structure of the folds.

    if has_key(a:state, 'multiline_string_start')
        let line.is_code = 0

        if line.text =~# a:state.multiline_string_start
            unlet a:state.multiline_string_start
        endif

    elseif line.text =~# s:string_start_pattern
        if line.text !~# s:string_start_end_pattern
            let a:state.multiline_string_start = 
                        \ matchlist(line.text, s:string_start_pattern)[1]
        endif

    " Identify lines that are continued from previous lines, e.g. if the 
    " previous line ended with a backslash.  I'd also like to include open 
    " parentheses in this logic, but I'd have to find a way to make it robust 
    " against parentheses in strings...

    elseif has_key(a:state, 'continuation_backslash')
        let line.is_code = 0
        unlet a:state.continuation_backslash

    elseif line.text =~# '\\$'
        let a:state.continuation_backslash = 1

    " Specially handle the case where a long argument list is ended on it's own 
    " line at the same indentation level as the `def` keyword.  This is the 
    " style enforced by the Black formatter, see issues #4, #8, #12 (I keep 
    " having problems with this regexp, lol).

    elseif line.text =~# '^\s*)\s*\(->\s*.\+\)\?:\s*$'
      let line.is_code = 0

    " Also keep track of blank lines, which can affect where folds end.

    elseif line.text =~# s:blank_pattern
        let line.is_code = 0
        let line.is_blank = 1

    endif

    return line
endfunction

function! s:InitFold(line) abort "{{{1
    let fold = {}
    let fold.parent = {}
    let fold.type = ""
    let fold.lnum = a:line.lnum
    let fold.level = -1
    let fold.indent = a:line.indent
    let fold.ignore = a:line.text =~# s:manual_ignore_pattern
    let fold.min_lines = 0
    let fold.max_indent = -1
    let fold.max_level = -1
    let fold.num_blanks_below = 0
    let fold.opening_line = a:line
    let fold.inside_line = {}   " The last line that should be in the fold.
    let fold.outside_line = {}  " The first line that shouldn't be in the fold.
    let fold.next_fold = {}
    let fold.FindClosingInfo = function('s:UndefinedClosingLine')

    function! fold.NumLines()
        let l:open = self.opening_line.lnum
        let l:close = get(self.inside_line, 'lnum', line('$'))
        return l:close - l:open + 1
    endfunction

    function! fold.InsideLnumOrEOF()
        if self.inside_line == {}
            return line('$')
        else
            return self.inside_line.lnum
        endif
    endfunction

    if ! a:line.is_code
        " Don't match any of the other patterns if this line is a comment of a 
        " multiline string.

    elseif a:line.text =~# s:import_pattern
        let fold.type = 'import'
        let fold.FindClosingInfo = function('s:CloseImports')
        let fold.min_lines = 4

    elseif a:line.text =~# s:decorator_pattern
        let fold.type = 'decorator'
        let fold.FindClosingInfo = function('s:CloseDecorator')

    elseif a:line.text =~# s:class_pattern
        let fold.type = 'class'
        let fold.FindClosingInfo = function('s:CloseBlock')
        let fold.num_blanks_below = 2

    elseif a:line.text =~# s:function_pattern
        let fold.type = 'function'
        let fold.FindClosingInfo = function('s:CloseBlock')
        let fold.num_blanks_below = 1

    elseif a:line.text =~# s:data_struct_pattern
        let fold.type = 'struct'
        let fold.FindClosingInfo = function('s:CloseDataStructure')
        let fold.max_indent = 0
        let fold.min_lines = 6

    elseif a:line.text =~# s:docstring_pattern 
                \ && a:line.text !~# s:string_start_end_pattern

        let fold.type = 'doc'
        let fold.FindClosingInfo = function('s:CloseOnPattern')
        let fold.close_pattern = matchlist(a:line.text, s:docstring_pattern)[1]
    endif

    return fold
endfunction

function! s:UndefinedClosingLine(lines, folds) abort dict "{{{1
    " Identify the last line that should be part of the fold (self.inside_line) 
    " and (optionally) the first line that should be not be part of it 
    " (self.outside_line).  If this latter information is provided, it may be 
    " used to include some extra lines in the fold (e.g.  blank lines between 
    " methods).  This is a virtual function that must be defined for each type 
    " of fold (e.g. class, function, docstring, etc.) 
    throw printf("No algorithm given to end fold of type '%s'", self.type)
endfunction

function! s:CloseOnPattern(lines, folds) abort dict "{{{1
    " `self.lnum` is 1-indexed, indices into `lines` are 0-indexed.
    let ii = self.lnum - 1

    for jj in range(ii+1, len(a:lines)-1)
        let line = a:lines[jj]

        if has_key(self, 'close_pattern') && line.text =~# self.close_pattern
            let self.inside_line = line
            return
        endif
    endfor
endfunction

function! s:CloseImports(lines, folds) abort dict "{{{1
    " `self.lnum` is 1-indexed, indices into `lines` are 0-indexed.
    let ii = self.lnum - 1
    let self.inside_line = a:lines[ii]
    let continuation_paren = 0
    let continuation_backslash = 0

    for jj in range(ii, len(a:lines)-1)
        let line = a:lines[jj]

        if continuation_paren
            let self.inside_line = line
            let continuation_paren = (line.text !~# ')')

        elseif continuation_backslash 
            let self.inside_line = line

        elseif line.text =~# s:import_pattern
            let self.inside_line = line
            let continuation_paren = (line.text =~# '(')

        elseif line.is_code && line.text !~# s:import_continue_pattern
            return
        endif

        let continuation_backslash = (line.text =~# '\\$')

        " Without this, each import line will try to open a new fold.
        if jj != ii && has_key(a:folds, line.lnum)
            let a:folds[line.lnum].ignore = 1
        endif
    endfor

endfunction

function! s:CloseDecorator(lines, folds) abort dict "{{{1
    let ii = self.lnum - 1

    " Find the class or function being decorated, and copy it's settings over.
    for jj in range(ii+1, len(a:lines)-1)
        let line = a:lines[jj]

        if ! has_key(a:folds, line.lnum)
            continue
        endif

        " Ignore any folds we encounter before the block, but respect if 
        " they've been manually ignored. 
        let l:fold = a:folds[line.lnum]
        let self.ignore = self.ignore || l:fold.ignore
        let l:fold.ignore = 1

        " Copy some settings over from the block we're decorating.
        if l:fold.type == 'function' || l:fold.type == 'class'
            call l:fold.FindClosingInfo(a:lines, a:folds)
            let self.type = l:fold.type
            let self.inside_line = l:fold.inside_line
            let self.outside_line = l:fold.outside_line
            let self.num_blanks_below = l:fold.num_blanks_below
            let self.min_lines = l:fold.min_lines + (l:fold.lnum - self.lnum)
            return
        endif
    endfor
endfunction

function! s:CloseBlock(lines, folds) abort dict "{{{1
    " `fold.lnum` is 1-indexed, indices into `lines` are 0-indexed.
    let ii = self.lnum - 1

    for jj in range(ii+1, len(a:lines)-1)
        let line = a:lines[jj]
        let prev_line = a:lines[jj-1]

        " The inside line is the last non-blank line before the change in 
        " indentation.
        if ! prev_line.is_blank
            let inside_line = prev_line
        endif

        " The outside line is the first line (excluding blanks, comments, and 
        " multiline strings) with an indent level equal to or lesser than the 
        " line that opened the fold.
        if line.is_code && line.indent <= self.opening_line.indent
            let self.inside_line = inside_line
            let self.outside_line = line
            return
        endif
    endfor
endfunction

function! s:CloseDataStructure(lines, folds) abort dict "{{{1
    call call('s:CloseBlock', [a:lines, a:folds], self)

    if self.outside_line.text =~# s:data_struct_close_pattern 
        let self.inside_line = self.outside_line
        let self.outside_line = {}
    endif
endfunction

function! s:FindDecoratorTitle(focus, foldstart, foldend) abort "{{{1
    " Step through the fold line-by-line looking for a class or function 
    " definition.
    for offset in range(0, a:foldend - a:foldstart)
        let line = getline(a:foldstart + offset)

        " We might want to label static methods.
        if line =~# s:decorator_pattern . '\(staticmethod\|classmethod\)'
            let a:focus.is_static = 1
        endif

        if line =~# s:block_pattern
            let a:focus.text = line
            let a:focus.offset = offset
            return
        endif
    endfor
endfunction

function! s:FindDocstringTitle(focus, foldstart, foldend) abort "{{{1
    let ii = matchend(a:focus.text, s:string_start_pattern.'\s*')
    let line = strpart(a:focus.text, ii)
    let indent = repeat(' ', indent(a:foldstart))

    if line !~# s:blank_pattern
        let a:focus.text = indent . line
        return
    endif

    for offset in range(1, a:foldend - a:foldstart)
        let line = getline(a:foldstart + offset)

        if line !~# s:blank_pattern
            let jj = matchend(line, '^\s*')
            let a:focus.text = indent . strpart(line, jj)
            let a:focus.offset = offset
            return
        endif
    endfor
endfunction

function! s:LowToHigh(x, y) abort "{{{1
    return str2nr(a:x) - str2nr(a:y)
endfunction

function! s:BufferWidth() abort "{{{1
    " The `:sign place` output contains two header lines.
    " The sign column is fixed at two columns, if present.
    redir =>a | exe "silent sign place buffer=".bufnr('') | redir end
    let signlist = split(a, '\n')

    " If there are line numbers, the `&numberwidth` setting defines their 
    " minimum width.  But we also have to check how many lines are in the file, 
    " because the actual width will be large enough to accomodate the biggest 
    " number. 
    let lineno_cols = max([&numberwidth, strlen(line('$')) + 1])

    return winwidth(0)
                \ - &foldcolumn
                \ - ((&number || &relativenumber) ? lineno_cols : 0)
                \ - (len(signlist) > 2 ? 2 : 0)

endfunction

" vim: ts=4 sts=4 sw=4
