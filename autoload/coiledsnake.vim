" Patterns {{{1
let s:blank_pattern = '^\s*$'
let s:comment_pattern = '^\s*#'
let s:import_pattern = '^\(import\|from\)'
let s:class_pattern = '^\s*class\s'
let s:function_pattern = '^\s*\(def\s\|if __name__\s==\)'
let s:block_pattern = join([s:class_pattern, s:function_pattern], '\|')
let s:decorator_pattern = '^\s*@'
let s:string_start_pattern = '[bBfFrRuU]\{0,2}\(''''''\|"""\)'
let s:string_start_end_pattern = s:string_start_pattern . '.*\1'
let s:docstring_pattern = '^\s*' . s:string_start_pattern
let s:docstring_close_pattern = '\(''''''\|"""\)'
let s:data_struct_pattern = '^\s*[a-zA-Z0-9_.]\+ = \({\|\[\|(\|'.s:string_start_pattern.'\)\s*$'
let s:data_struct_close_pattern = '^\s*\(}\|\]\|)\|''''''\|"""\)$'
let s:manual_open_pattern = '^\s*##'
let s:manual_ignore_pattern = '#$'
" }}}1

function! coiledsnake#FoldExpr(lnum) abort "{{{1
    if !exists('b:folds')
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
    for l:fold in values(folds)

        " Open a fold at the appropriate level on this line.
        let b:marks[l:fold.lnum] = '>' . l:fold.level

        " If no inside line was found, the fold reaches the end of the file and 
        " doesn't need to be closed.
        if l:fold.inside_line == {}
            continue

        " If an outside line was specified, allow the fold to include a certain 
        " number of blank lines, so long as it doesn't encroach on the outside 
        " line.
        elseif l:fold.outside_line != {}
            let buffer = 1 + !has_key(folds, l:fold.outside_line.lnum)
            let closing_lnum = max([
                    \ l:fold.inside_line.lnum,
                    \ min([
                        \ l:fold.inside_line.lnum + l:fold.num_blanks_below,
                        \ l:fold.outside_line.lnum - buffer])])

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

    if focus.text =~# s:block_pattern
        let fields = split(focus.text, '#')
        let next_line = getline(a:foldstart + focus.offset + 1)

        " Tags are taken to be parenthetical phrases found within an inline
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

        if next_line =~# s:docstring_pattern
            call add(flags, "doc")
        endif

    else
        let title = focus.text
        let flags = []
    endif

    " Format a succinct fold message.  The title is stripped of whitespace and 
    " truncated, if it is too long to fit on the screen.  The total number of 
    " folded lines are added as an extra tag, and all the flags are wrapped in 
    " parenthesis.

    let flags = add(flags, 1 + a:foldend - a:foldstart)
    let status = '(' . join(flags, ') (') . ')'

    let cutoff = &columns - strlen(status)
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

function! coiledsnake#DebugLines() abort  "{{{1
    let lines = s:LinesFromBuffer()

    if type(lines) != type([])
        echo "Lines is not a list:"
        echo lines
        return
    endif

    echo "#   Code? Blank? Level Text"
    for lnum in range(0, len(lines)-1)
        let line = lines[lnum]
        echo printf("%3s %5s %6s %5s %s",
                    \ get(line, 'lnum', '???'),
                    \ get(line, 'is_code', '?'),
                    \ get(line, 'is_blank', '?'),
                    \ get(line, 'fold_level', '?'),
                    \ get(line, 'text', '???'))
    endfor
endfunction

function! coiledsnake#DebugFolds() abort  "{{{1
    let lines = s:LinesFromBuffer()
    let folds = s:FoldsFromLines(lines)

    for lnum in keys(folds)
        echo printf('Line #%d', lnum)
        for attr in keys(folds[lnum])
            echo printf('  %s: %s', attr, folds[lnum][attr])
        endfor
        echo '----'
    endfor
endfunction

function! coiledsnake#DebugMarks() abort  "{{{1
    echo "#    Fold  Line"
    for lnum in range(1, line('$'))
        echo printf("%-3s  %4s  %s",
                    \ lnum,
                    \ coiledsnake#FoldExpr(lnum),
                    \ getline(lnum))
    endfor
endfunction

function! coiledsnake#DebugText() abort  "{{{1
    echo "#    Line"
    for lnum in range(1, line('$'))
        echo FoldText(lnum, lnum+1)
    endfor
endfunction

" }}}1

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
    for lnum in sort(keys(candidate_folds), 'N')
        let l:fold = candidate_folds[lnum]

        if l:fold.ignore
            continue
        endif

        " Figure out (roughly) where to close each fold.  This has to be done 
        " after all the folds have been loaded, so that earlier folds can 
        " supercede later ones.
        call l:fold.FindClosingInfo(a:lines, candidate_folds)

        if l:fold.ignore
            continue
        endif

        if l:fold.NumLines() < l:fold.min_lines
            continue
        endif

        if l:fold.max_level > 0 && l:fold.level > l:fold.max_level
            continue
        endif

        let folds[l:fold.lnum] = l:fold
    endfor

    return folds
endfunction

function! s:InitLine(lnum, state) abort "{{{1
    let line = {}
    let line.lnum = a:lnum
    let line.text = getline(a:lnum)
    let line.indent = indent(a:lnum)
    let line.fold_level = line.indent / &shiftwidth + 1
    let line.is_code = 1
    let line.is_blank = 0

    " Work out which lines are in comments or multiline strings and mark them 
    " as being 'not code'.  These need to be (largely) ignored by the folding 
    " machinery, since they could contain anything but don't affect the 
    " structure of the code.

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

    elseif line.text =~# s:comment_pattern
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
    let fold.type = ""
    let fold.lnum = a:line.lnum
    let fold.level = a:line.fold_level
    let fold.opening_line = a:line
    let fold.inside_line = {}   " The last line that should be in the fold.
    let fold.outside_line = {}  " The first line that shouldn't be in the fold.
    let fold.num_blanks_below = 0
    let fold.min_lines = 0
    let fold.max_level = -1
    let fold.ignore = a:line.text =~# s:manual_ignore_pattern
    let fold.FindClosingInfo = function('s:UndefinedClosingLine')

    function! fold.NumLines()
        let l:open = self.opening_line.lnum
        let l:close = get(self.inside_line, 'lnum', line('$'))
        return l:close - l:open + 1
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
        let fold.max_level = 1

    elseif a:line.text =~# s:docstring_pattern
        let fold.type = 'doc'
        let fold.FindClosingInfo = function('s:CloseOnPattern')
        let fold.close_pattern = s:docstring_close_pattern
    endif

    return fold
endfunction

function! s:UndefinedClosingLine(lines, folds) abort dict "{{{1
    " Return a dictionary containing the last line that should be part of the 
    " fold (retval.inside_line) and (optionally) the first line that should be 
    " not be part of it (retval.outside_line).  If this latter information is 
    " provided, it may be used to include some extra lines in the fold (e.g. 
    " blank lines between methods).  This is a virtual function that must be 
    " defined for each type of fold (e.g. class, function, docstring, etc.) 
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

    for jj in range(ii+1, len(a:lines)-1)
        let line = a:lines[jj]
        let prev_line = a:lines[jj-1]

        if line.text !~# s:import_pattern
            let self.inside_line = prev_line
            return
        endif

        if has_key(a:folds, line.lnum)
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
        if line.is_code && line.fold_level <= self.level
            let self.inside_line = inside_line
            let self.outside_line = line
            return
        endif
    endfor
endfunction

function! s:CloseDataStructure(lines, folds) abort dict "{{{1
    let CloseBlock = function('s:CloseBlock', [], self)
    call CloseBlock(a:lines, a:folds)

    if self.outside_line.text =~# s:data_struct_close_pattern 
        let self.inside_line = self.outside_line
        let self.outside_line = {}
    endif
endfunction

function! s:FindDecoratorTitle(focus, foldstart, foldend) abort "{{{1
    " Step through the fold line-by-line looking for a class or function 
    " definition.
    for offset in range(1, a:foldend - a:foldstart)
        let line = getline(a:foldstart + offset)

        if line =~# s:block_pattern
            let a:focus.text = line
            let a:focus.offset = offset
            return
        endif
    endfor
endfunction

function! s:FindDocstringTitle(focus, foldstart, foldend) abort "{{{1
    let ii = matchend(a:focus.text, s:string_start_pattern.'\s*')
    let line = a:focus.text[ii:len(a:focus.text)]

    if line !~# s:blank_pattern
        let a:focus.text = line
        return
    endif

    for offset in range(1, a:foldend - a:foldstart)
        let line = getline(a:foldstart + offset)

        if line !~# s:blank_pattern
            let a:focus.text = line
            let a:focus.offset = offset
            return
        endif
    endfor
endfunction

