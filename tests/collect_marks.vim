" Collect fold marks for the current buffer and write to g:marks_output_file.
let marks = []
for lnum in range(1, line('$'))
    call add(marks, coiledsnake#FoldExpr(lnum))
endfor
call writefile(marks, g:marks_output_file)
qa!
