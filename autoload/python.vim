let s:manual_open_pattern = '^\s*##'
let s:manual_ignore_pattern = '#$'
let s:blank_pattern = '^\s*$'
let s:import_pattern = '^\(import\|from\)'
let s:decorator_pattern = '^\s*@'
let s:block_pattern = '^\s*\(class\s\|def\s\|if __name__\s==\)'
let s:string_start_pattern = '[bBfFrRuU]\{0,2}\(''''''\|"""\)'
let s:string_start_end_pattern = s:string_start_pattern . '.*\1'
let s:docstring_pattern = '^\s*' . s:string_start_pattern
let s:docstring_close_pattern = '^\s*\(''''''\|"""\)'
let s:data_struct_pattern = '^[a-zA-Z0-9_.]\+ = \({\|[\|(\|'.s:string_start_pattern.'\)\s*$'
let s:data_struct_close_pattern = '^\s*\(}\|]\|)\|''''''\|"""\)$'

function! FoldExpr(lnum) "{{{1
    if !exists('b:folds')
        let b:folds = FindFolds()
    endif
    return get(b:folds, a:lnum, '=')
endfunction

function! FoldText(foldstart, foldend)    " {{{1

    " Find the line that should be used to summarize the fold.  This is usually 
    " the first line, but decorators are explicitly skipped.

    let line = getline(a:foldstart)
    let offset = 0

    while line =~ '^\s*@' || line =~ '^\s*"""'
        let offset += 1
        let line = getline(a:foldstart + offset)
    endwhile

    let next_line = getline(a:foldstart + offset + 1)

    " Break the line into two parts: a title and a set of flags.  The title 
    " will be left-justified, while the flags will be concatenated together and 
    " right-justified.

    if line =~ s:block_pattern
        let fields = split(line, '#')

        " Tags are taken to be parenthetical phrases found within an inline
        " comment.  Line that don't have an inline comment can be trivially 
        " processed, so this case is handled specially.

        if len(fields) == 1
            let title = line
            let flags = []
        else
            let title = fields[0]
            let flags = matchlist(fields[1], '(\([^)]\+\))')
            let flags = filter(flags[1:], 'v:val != ""')
        endif

        if next_line =~ s:docstring_pattern
            call add(flags, "doc")
        endif

    else
        let title = line
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

function! FoldTextCaller() "{{{1
    return FoldText(v:foldstart, v:foldend)
endfunction
function! FindFolds()  "{{{1
    echo 'FindFolds'
    let b:folds = {}
    let lines = LinesFromBuffer()

    for ii in range(len(lines))
        let line = lines[ii]

        " If the line can't open a fold, move on.
        if line.can_open == 0 
            continue
        endif

        " If the line is prevented from opening a fold by the line above it, 
        " move on.
        if ii > 0
            let previous_line = lines[ii-1]
            if previous_line.can_open_below == 0
                continue
            endif
        endif

        " Open a fold at the appropriate level on this line.
        let b:folds[line.lnum] = '>' . line.fold_level

        " Figure out where to close this fold.

        " Find the last line that should be in this fold and the first line 
        " that should be outside it.  This determination is based mostly on 
        " indentation, with a few exceptions.  There may be a number of empty 
        " lines between these last and first lines.
        let outside_line = {}
        let inside_line = line

        for jj in range(ii+1, len(lines)-1)
            let prev_line = lines[jj-1]
            let next_line = lines[jj]

            " Don't count lines that can't close folds, e.g. blank lines, 
            " multi-line strings, and lines that follow decorators.
            if next_line.fold_level <= line.fold_level 
                        \ && next_line.can_close
                        \ && prev_line.can_open_below
                let outside_line = next_line
                break
            endif
            if next_line.type != 'blank'
                let inside_line = next_line
            endif
        endfor

        " If we reach the end of the buffer without finding any lines, then we 
        " don't need to close the fold.
        if outside_line == {}
            continue 
        endif

        " If the closing line can be included 
        if line.can_close_on_same_indent != ''
                    \ && outside_line.text =~# line.can_close_on_same_indent
            let closing_lnum = outside_line.lnum

        " If the outside line can open its own fold, then allow one blank line 
        " after the fold.
        elseif outside_line.can_open 
            let closing_lnum = min([
                        \ outside_line.lnum - 1,
                        \ inside_line.lnum + 1])

        " Otherwise, close the fold on its last line.
        else
            let closing_lnum = inside_line.lnum
        endif

        " Indicate that the fold should be closed, but don't overwrite any 
        " previous entries.  Due to the way the code is organized, any previous 
        " entries will be higher level folds, and we want those to take 
        " precedence.
        if ! has_key(b:folds, closing_lnum)
            let b:folds[closing_lnum] = '<' . line.fold_level
        endif
    endfor

    return b:folds
endfunction

function! ClearFolds() "{{{1
    if exists('b:folds')
        unlet b:folds
    endif
    echo 'ClearFolds'
endfunction

function! LinesFromBuffer()  "{{{1
    let lines = []
    let state = {'lines': lines}

    for lnum in range(1, line('$'))
        let line = ParseLine(lnum, state)
        call add(lines, line)
    endfor

    return lines
endfunction

function! ParseLine(lnum, state)  "{{{1
    let line = {}
    let line.type = 'code'
    let line.lnum = a:lnum
    let line.text = getline(a:lnum)
    let line.fold_level = indent(a:lnum) / &shiftwidth + 1
    let line.can_open = 0
    let line.can_open_below = 1
    let line.can_close = 1
    let line.can_close_on_same_indent = ''

    if line.text =~# s:manual_ignore_pattern
        let line.can_open = 0

    elseif line.text =~# s:manual_open_pattern
        let line.can_open = 1

    endif

    if has_key(a:state, 'multiline_string_start')
        let line.type = 'string'
        let line.can_close = 0

        if line.text =~# a:state.multiline_string_start
            unlet a:state.multiline_string_start
        endif


    else
        if line.text =~# s:blank_pattern
            let line.type = 'blank'
            let line.can_close = 0

        elseif line.text =~# s:import_pattern
            let line.type = 'import'

        elseif line.text =~# s:decorator_pattern
            let line.type = 'decorator'
            let line.can_open = 1
            let line.can_open_below = 0

        elseif line.text =~# s:block_pattern
            let line.type = 'block'
            let line.can_open = 1

        elseif line.text =~# s:data_struct_pattern
            let line.type = 'struct'
            let line.can_open = 1
            let line.can_close_on_same_indent = s:data_struct_close_pattern

        elseif line.text =~# s:docstring_pattern
            let line.type = 'doc'
            let line.can_open = 1
            let line.can_close_on_same_indent = s:docstring_close_pattern
        endif

        if line.text =~# s:string_start_pattern
            if line.text !~# s:string_start_end_pattern
                let a:state.multiline_string_start =
                            \ matchlist(line.text, s:string_start_pattern)[1]
            endif
        endif
    endif

    return line
endfunction

function! DebugLines()  "{{{1
    let lines = LinesFromBuffer()

    if type(lines) != type([])
        echo "Lines is not a list:"
        echo lines
        return
    endif

    echo "Type       CO OB CC  Lvl  Line"
    for lnum in range(0, len(lines)-1)
        let line = lines[lnum]
        echo printf("%-9s  %2s %2s %2s  %3s  %s",
                    \ get(line, 'type', '???'),
                    \ get(line, 'can_open', '??'),
                    \ get(line, 'can_open_below', '??'),
                    \ get(line, 'can_close', '??'),
                    \ get(line, 'fold_level', '???'),
                    \ get(line, 'text', '???'))
    endfor
endfunction

function! DebugFolds() abort  "{{{1
    echo "#    Fold  Line"
    for lnum in range(1, line('$'))
        echo printf("%-3s  %4s  %s",
                    \ lnum,
                    \ FoldExpr(lnum),
                    \ getline(lnum))
    endfor
endfunction

function! DebugText() abort  "{{{1
    echo "#    Line"
    for lnum in range(1, line('$'))
        echo FoldText(lnum, lnum+1)
    endfor
endfunction

" }}}1
