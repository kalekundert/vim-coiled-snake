" Patterns {{{1
let s:blank_pattern = '^\s*$'
let s:comment_pattern = '^\s*#'
let s:import_pattern = '^\(import\|from\)'
let s:class_pattern = '^\s*class\s'
let s:function_pattern = '^\s*\(\(async\s\+\)\?def\s\|if __name__\s==\)'
let s:block_pattern = join([s:class_pattern, s:function_pattern], '\|')
let s:decorator_pattern = '^\s*@'
let s:multiline_string_start_pattern = '\v[bBfFrRuU]*(''''''|""")\\?'
let s:multiline_string_start_end_pattern = s:multiline_string_start_pattern . '.*\1'
let s:uniline_string_start_pattern = '\v(''''''|"""|''|")' " triple-quotes first, so that the longest match is made.
let s:uniline_string_end_pattern = '\\@<!(\\\\)*\\@<!\1' " https://stackoverflow.com/questions/42598040/python-regex-for-matching-odd-number-of-consecutive-backslashes
let s:uniline_string_pattern = s:uniline_string_start_pattern . '.{-}' . s:uniline_string_end_pattern
let s:docstring_pattern = '^\s*' . s:multiline_string_start_pattern
let s:data_struct_pattern = '\v(\{|\[|\()\s*$'
let s:string_struct_pattern = s:multiline_string_start_pattern . 'START\s*$'
let s:manual_ignore_pattern = '#$'
" }}}1

function! coiledsnake#FoldExpr(lnum) abort "{{{1
    if !exists('b:coiled_snake_marks')
        let b:coiled_snake_marks = coiledsnake#RefreshFolds()
    endif
    return get(b:coiled_snake_marks, a:lnum, '=')
endfunction

function! coiledsnake#FoldText() abort "{{{1
    return coiledsnake#FormatText(v:foldstart, v:foldend)
endfunction

function! coiledsnake#ClearFolds() abort "{{{1
    if exists('b:coiled_snake_marks')
        unlet b:coiled_snake_marks
        set foldmethod=expr
    endif
endfunction

function! coiledsnake#RefreshFolds() abort "{{{1
    let b:coiled_snake_marks = {}
    let lines = s:LinesFromBuffer()
    let folds = s:FoldsFromLines(lines)

    " Cache where each fold should open and close.
    for lnum in sort(keys(folds), 's:LowToHigh')
        let l:fold = folds[lnum]

        " Open a fold at the appropriate level on this line.
        let b:coiled_snake_marks[l:fold.lnum] = '>' . l:fold.level

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
                    \ l:fold.outside_line.lnum - 1])

        " If only an inside line was specified, close the fold exactly on that 
        " line.
        else 
            let closing_lnum = l:fold.inside_line.lnum
        endif

        " Indicate that the fold should be closed, but don't overwrite any 
        " previous entries.  Due to the way the code is organized, any previous 
        " entries will be higher level folds, and we want those to take 
        " precedence.
        if ! has_key(b:coiled_snake_marks, closing_lnum)
            let b:coiled_snake_marks[closing_lnum] = '<' . l:fold.level
        endif

        " Ignore folds that end up opening and closing on the same line.
        if closing_lnum <= l:fold.lnum
            unlet b:coiled_snake_marks[closing_lnum]
        endif
    endfor

    return b:coiled_snake_marks
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

    if g:coiled_snake_explicit_sign_width != 0
        let trailing = g:coiled_snake_explicit_sign_width
        let trailing = ' ' . repeat(' ', rightpadding)
    else
        let trailing = ''
    endif

    return title . padding . status . trailing

endfunction

function! coiledsnake#LoadSettings() abort "{{{1
    call s:SetIfUndef('g:coiled_snake_set_foldexpr', 1)
    call s:SetIfUndef('g:coiled_snake_set_foldtext', 1)
    call s:SetIfUndef('g:coiled_snake_foldtext_flags', ['doc', 'static'])
    call s:SetIfUndef('g:coiled_snake_explicit_sign_width', 0)
endfunction

function! coiledsnake#EnableFoldText() abort "{{{1
    let &l:foldtext = 'coiledsnake#FoldText()'
endfunction

function! coiledsnake#EnableFoldExpr() abort "{{{1
    let &l:foldexpr = 'coiledsnake#FoldExpr(v:lnum)'
    let &l:foldmethod = 'expr'
    augroup CoiledSnake
        autocmd TextChanged,InsertLeave <buffer> call coiledsnake#ClearFolds()
    augroup END
endfunction

function! coiledsnake#ResetFoldText() abort "{{{1
    " Only reset if the value is the same as we initially set
    if &foldtext ==# 'coiledsnake#FoldText()'
        let &l:foldtext = &g:foldtext
    endif
endfunction

function! coiledsnake#ResetFoldExpr() abort "{{{1
    " Only reset if the value is the same as we initially set
    if &foldexpr ==# 'coiledsnake#FoldExpr(v:lnum)'
        let &l:foldexpr = &g:foldexpr
    endif
    if &foldmethod ==# 'expr'
        let &l:foldmethod = &g:foldmethod
    endif
    augroup CoiledSnake
        autocmd! TextChanged,InsertLeave <buffer>
    augroup END
endfunction

function! coiledsnake#DebugLines() abort "{{{1
    let lines = s:LinesFromBuffer()

    if type(lines) != type([])
        echo "Lines is not a list:"
        echo lines
        return
    endif

    echo "#   Blank? Cont? Indent Paren Code"
    for lnum in range(0, len(lines)-1)
        let line = lines[lnum]
        echo printf("%-3s %6s %5s %6s %5s %s",
                    \ get(line, 'lnum', '???'),
                    \ get(line, 'is_blank', '?'),
                    \ get(line, 'is_continuation', '?'),
                    \ get(line, 'indent', '?'),
                    \ get(line, 'paren_level', '?'),
                    \ get(line, 'code', '???'))
    endfor
endfunction

function! coiledsnake#DebugFolds() abort "{{{1
    let lines = s:LinesFromBuffer()
    let folds = s:FoldsFromLines(lines)

    echo "  #  In Out Type      Parent    Lvl Ig N? >? Text"
    for lnum in sort(keys(folds), 's:LowToHigh')
        let fold = folds[lnum]
        echo printf("%3s %3s %3s %-9.9s %-9.9s %3s %2s %2s %2s %s",
                    \ get(l:fold, 'lnum', '???'),
                    \ get(l:fold.inside_line, 'lnum', 'EOF'),
                    \ get(l:fold.outside_line, 'lnum', 'EOF'),
                    \ get(l:fold, 'type', '???'),
                    \ get(l:fold.parent, 'type', ''),
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
        " This looks better is there's some sort of gutter on the left.
        echo lnum coiledsnake#FormatText(lnum, lnum+1)
    endfor
endfunction

function! coiledsnake#DebugBufferWidth() abort "{{{1
    echo s:BufferWidth()
endfunction
" }}}1

function! s:SetIfUndef(name, value) abort " {{{1
    if ! exists(a:name)
        let {a:name} = a:value
    endif
endfunction

function! s:LinesFromBuffer() abort "{{{1
    let lines = []
    let state = {'lines': lines, 'paren_level': 0}

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

    " Make note of consecutive folds.  Blank lines may be collapsed between 
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
    let line.code = line.text  " The line with strings and comments removed.
    let line.indent = indent(a:lnum)
    let line.ignore_indent = 0
    let line.paren_level = 0
    let line.is_blank = 0
    let line.is_comment = 0
    let line.is_continuation = 0

    " Handle strings and comments first, because they will prune non-code 
    " content that might otherwise confuse later parsers.
    call s:InitLineString(line, a:state)
    call s:InitLineComment(line, a:state)
    call s:InitLineParen(line, a:state)
    call s:InitLineBackslash(line, a:state)
    call s:InitLineBlank(line, a:state)

    return line
endfunction

function! s:InitLineString(line, state) "{{{1
    " Ignore lines in multiline strings.
    if has_key(a:state, 'multiline_string_delim')
        let a:line.ignore_indent = 1

        if a:line.code =~# a:state.multiline_string_delim
            let a:line.code = 'END' . a:state.multiline_string_delim . 
                        \ split(
                        \       a:line.code,
                        \       a:state.multiline_string_delim,
                        \       1,
                        \ )[-1]
            unlet a:state.multiline_string_delim
        else
            let a:line.code = ''
        endif

        return
    endif

    " Ignore text within strings.
    
    let a:line.code = substitute(
                    \       a:line.code,
                    \       s:uniline_string_pattern,
                    \       '\1\1',
                    \       'g',
                    \ )

    " Check to see if this line begins a multiline string.
    if a:line.code =~# s:multiline_string_start_pattern && a:line.code !~# s:multiline_string_start_end_pattern
        let a:state.multiline_string_delim = matchlist(
                    \       a:line.code,
                    \       s:multiline_string_start_pattern
                    \ )[1]
        let a:line.code = split(
                    \       a:line.code,
                    \       a:state.multiline_string_delim,
                    \       1
                    \ )[0]
                    \ . a:state.multiline_string_delim . 'START'
    endif

endfunction

function! s:InitLineComment(line, state) "{{{1
    let a:line.code = substitute(a:line.code, '\s*#.*$', '', '')
    if a:line.code =~# s:blank_pattern
        let a:line.is_comment = 1
    endif
endfunction

function! s:InitLineParen(line, state) "{{{1
    let a:line.paren_level     = a:state.paren_level
    let a:line.is_continuation = a:line.is_continuation || a:line.paren_level > 0
    let a:line.ignore_indent   = a:line.ignore_indent   || a:line.paren_level > 0

    " Count opening parentheses after the assignment, so that the line with the 
    " first parenthesis in not considered to be 'parenthesized'.
    let a:state.paren_level += count(a:line.code, '(')
    let a:state.paren_level += count(a:line.code, '[')
    let a:state.paren_level += count(a:line.code, '{')

    let a:state.paren_level -= count(a:line.code, ')')
    let a:state.paren_level -= count(a:line.code, ']')
    let a:state.paren_level -= count(a:line.code, '}')
endfunction

function! s:InitLineBackslash(line, state) "{{{1
    if has_key(a:state, 'continuation_backslash')
        let a:line.ignore_indent = 1
        let a:line.is_continuation = 1
        unlet a:state.continuation_backslash
    endif

    if a:line.code =~# '\\$'
        let a:state.continuation_backslash = 1
    endif
endfunction

function! s:InitLineBlank(line, state) "{{{1
    " Keep track of blank lines, which can affect where folds end.

    " Use `line.text` instead of `line.code`, because we want to know if the 
    " line is truly blank.
    if a:line.text =~# s:blank_pattern
        let a:line.is_blank = 1
    endif
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

    if a:line.code =~# s:import_pattern
        let fold.type = 'import'
        let fold.FindClosingInfo = function('s:CloseImports')
        let fold.min_lines = 4

    elseif a:line.code =~# s:decorator_pattern
        let fold.type = 'decorator'
        let fold.FindClosingInfo = function('s:CloseDecorator')

    elseif a:line.code =~# s:class_pattern
        let fold.type = 'class'
        let fold.FindClosingInfo = function('s:CloseBlock')
        let fold.num_blanks_below = 2

    elseif a:line.code =~# s:function_pattern
        let fold.type = 'function'
        let fold.FindClosingInfo = function('s:CloseBlock')
        let fold.num_blanks_below = 1

    elseif a:line.code =~# s:data_struct_pattern
        let fold.type = 'struct'
        let fold.FindClosingInfo = function('s:CloseDataStructure')
        let fold.max_indent = 0
        let fold.min_lines = 6

    elseif a:line.code =~# s:string_struct_pattern 
        let fold.FindClosingInfo = function('s:CloseOnPattern')
        let fold.close_pattern = 'END' . matchlist(a:line.code, s:string_struct_pattern)[1]

        if a:line.code =~# s:docstring_pattern && a:line.paren_level == 0
            let fold.type = 'doc'
        else
            let fold.type = 'struct'
            let fold.max_indent = 0
            let fold.min_lines = 6
        endif
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

        if has_key(self, 'close_pattern') && line.code =~# self.close_pattern
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

        if line.code =~# s:import_pattern || line.is_continuation
            let self.inside_line = line

        elseif line.code =~# s:blank_pattern

        else
            return
        endif

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
    let end = {}

    for jj in range(ii+1, len(a:lines)-1)
        let line = a:lines[jj]
        let prev_line = a:lines[jj-1]

        " The inside line is the last non-blank line before the change in 
        " indentation.
        if ! prev_line.is_blank
            let inside_line = prev_line
        endif

        " The outside line is the first line that should not be part of the 
        " fold, based on indentation.  Comments are handled specially.  They 
        " are the outside line if (i) they are dedented and (ii) they aren't 
        " immediately followed by lines that would be included in the fold.
        if line.is_blank || line.ignore_indent
            continue
        elseif line.indent > self.opening_line.indent
            let end = {}
        elseif line.is_comment && ! len(end)
            let end = {'inside_line': inside_line, 'outside_line': line}
        else
            if ! len(end)
                let end = {'inside_line': inside_line, 'outside_line': line}
            endif
            break
        endif
    endfor

    if len(end)
        let self.inside_line = end['inside_line']
        let self.outside_line = end['outside_line']
    endif
endfunction

function! s:CloseDataStructure(lines, folds) abort dict "{{{1
    " `self.lnum` is 1-indexed, indices into `lines` are 0-indexed.
    let ii = self.lnum - 1
    let self.inside_line = a:lines[ii]

    for jj in range(ii+1, len(a:lines)-1)
        let line = a:lines[jj]

        if line.paren_level > self.opening_line.paren_level
            let self.inside_line = line
        else
            return
        endif
    endfor
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
    let ii = matchend(a:focus.text, s:multiline_string_start_pattern.'\s*')
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
    " Getting the 'usable' window width means dealing with a lot of corner 
    " cases.  See: https://stackoverflow.com/questions/26315925/get-usable-window-width-in-vim-script/52049954#52049954
    let width = winwidth(0)

    " If there are line numbers, the `&numberwidth` setting defines their 
    " minimum width.  But we also have to check how many lines are in the file, 
    " because the actual width will be large enough to accommodate the biggest 
    " number. 
    let numberwidth = max([&numberwidth, strlen(line('$')) + 1])
    let numwidth = (&number || &relativenumber) ? numberwidth : 0

    " If present, the column indicating the fold will be one character wide.
    let foldwidth = &foldcolumn

    if foldwidth =~# 'auto' "neovim
        " we check if the cache exists. if yes, then we check if the cache is
        " up-to-date by checking current b:changedtick with that of the cache.
        " If they match, we use the cached value for foldwidth
        " If they don't match, (ie. buffer changed since last caching),
        " we re-calculate foldwidth and save it in the cache
        if !exists('b:coiled_snake_cached_foldwidth') || b:changedtick != b:coiled_snake_cached_foldwidth[0]
            let maxfoldwidth = (foldwidth =~# 'auto:') ? (split(foldwidth, ':')[1]) : 9
            let maxfolddepth = 0
            for lnum in range(1, line('$'))
                let currentfolddepth = foldlevel(lnum)
                if currentfolddepth > maxfolddepth
                    let maxfolddepth = currentfolddepth
                endif
            endfor
            if maxfolddepth > maxfoldwidth
                let foldwidth = maxfoldwidth
            else
                let foldwidth = maxfolddepth
            endif
            let b:coiled_snake_cached_foldwidth = deepcopy([b:changedtick, foldwidth]) "deepcopy() due to b:changedtick
        else
            let foldwidth = b:coiled_snake_cached_foldwidth[1]
        endif
    endif

    if g:coiled_snake_explicit_sign_width != 0
        let signwidth = g:coiled_snake_explicit_sign_width
    elseif &signcolumn == 'yes'
        let signwidth = 2
    elseif &signcolumn =~ 'yes'
        let signwidth = &signcolumn
        if signwidth =~ ':'
            let signwidth = split(signwidth, ':')[1]
        endif
        let signwidth *= 2  " each signcolumn is 2-char wide
    elseif &signcolumn == 'auto'
        " The `:sign place` output contains two header lines.
        " The sign column is fixed at two columns, if present.
        let supports_sign_groups = has('nvim-0.4.2') || has('patch-8.1.614')
        let signlist = execute(printf('sign place ' . (supports_sign_groups ? 'group=* ' : '') . 'buffer=%d', bufnr('')))
        let signlist = split(signlist, "\n")
        let signwidth = len(signlist) > 2 ? 2 : 0
    elseif &signcolumn =~ 'auto'    " i.e. neovim
        let signwidth = 0
        if len(sign_getplaced(bufnr(),{'group':'*'})[0].signs) " signs exist
            let signwidth = 0
            for l:sign in sign_getplaced(bufnr(),{'group':'*'})[0].signs
                let lnum = l:sign.lnum
                let signs = len(sign_getplaced(bufnr(),{'group':'*', 'lnum':lnum})[0].signs)
                let signwidth = (signs > signwidth ? signs : signwidth)
            endfor
        endif
        let signwidth *= 2  " each signcolumn is 2-char wide
    else
        let signwidth = 0
    endif

    return width - numwidth - foldwidth - signwidth
endfunction
" }}}1

" vim: ts=4 sts=4 sw=4 fdm=marker et sr
