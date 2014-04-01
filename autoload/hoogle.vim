
function! hoogle#hoogle(symbol)
   let l:qualAndSym = s:split_module_qualifier_and_symbol(a:symbol)
   if l:qualAndSym[1] ==# ''
      return
   endif

   let l:output = system(hoogle#browser() . ' ' . shellescape(hoogle#url() . l:qualAndSym[1]))
endfunction


function! hoogle#browser()
   return get(g:, 'hoogle_browser', 'firefox')
endfunction


function! hoogle#url()
   return get(g:, 'hoogle_url', 'https://www.fpcomplete.com/hoogle?exact=on&q=')
endfunction


function! s:split_module_qualifier_and_symbol(symbol)
   let l:symbol = s:get_symbol(a:symbol)
   if l:symbol ==# ''
      return []
   endif

   let l:words = split(l:symbol, '\.')
   if len(l:words) <= 1
      return ['', l:symbol]
   endif

   let l:moduleWords = []
   let l:symbolWords = []
   let l:nonModuleWordFound = 0
   " consider every word starting with an upper alphabetic 
   " character to be part of the module qualifier, until a word
   " starting with a non upper alphabetic character or a non
   " alphabetic character is found
   for l:word in l:words
      if l:nonModuleWordFound == 0 && l:word =~# '\v^\u+\w*$'
         let l:moduleWords += [l:word]
      else
         let l:symbolWords += [l:word]
         let l:nonModuleWordFound = 1
      endif
   endfor

   " If there're no symbol words, than we might have a qualified
   " data type e.g: 'T.Text', so we're assuming, that the last
   " module word is specifying the symbol.
   if len(l:symbolWords) == 0 && len(l:moduleWords) >= 2
      let l:symbolWords += [l:moduleWords[-1]]
      let l:moduleWords = l:moduleWords[0 : len(l:moduleWords) - 2]
   endif

   return [join(l:moduleWords, '.'), join(l:symbolWords, '')]
endfunction


function! hoogle#test_split_module_qualifier_and_symbol()
   let l:tests = [
      \ ['data', ['', 'data']],
      \ ['Data', ['', 'Data']],
      \ ['T.Text', ['T', 'Text']],
      \ ['Data.Text', ['Data', 'Text']],
      \ ['Data.Text.Text', ['Data.Text', 'Text']],
      \ ['Data.Text.pack', ['Data.Text', 'pack']],
      \ ['.&.', ['', '.&.']],
      \ ['.|.', ['', '.|.']]
      \ ]

   for l:test in l:tests
      let l:result = s:split_module_qualifier_and_symbol(l:test[0])
      if l:result !=# l:test[1]
         let l:refStr = '[' . l:test[1][0] . ', ' . l:test[1][1] . ']'
         let l:resultStr = ''
         if len(l:result) == 2
            let l:resultStr = '[' . l:result[0] . ', ' . l:result[1] . ']'
         endif

         let l:errmsg = 'Test failed for ' . l:test[0] . ': Expected=' . l:refStr . '. Got=' . l:resultStr
         call s:print_error(l:errmsg)
      endif
   endfor
endfunction


function! s:get_symbol(symbol)
  let l:symbol = a:symbol

  " No symbol argument given, probably called from a keyboard shortcut
  if l:symbol ==# ''
    " Get the symbol under the cursor
    let l:symbol = s:extract_identifier(getline("."), col("."))
    if l:symbol ==# ''
      call s:print_warning('No Symbol Under Cursor')
    endif
  endif

  return l:symbol
endfunction


" a verbatim copy from vim-hdevtools
function! s:extract_identifier(line_text, col)
  if a:col > len(a:line_text)
    return ''
  endif

  let l:index = a:col - 1
  let l:delimiter = '\s\|[(),;`{}"[\]]'

  " Move the index forward till the cursor is not on a delimiter
  while match(a:line_text[l:index], l:delimiter) == 0
    let l:index = l:index + 1
    if l:index == len(a:line_text)
      return ''
    endif
  endwhile

  let l:start_index = l:index
  " Move start_index backwards until it hits a delimiter or beginning of line
  while l:start_index > 0 && match(a:line_text[l:start_index-1], l:delimiter) < 0
    let l:start_index = l:start_index - 1
  endwhile

  let l:end_index = l:index
  " Move end_index forwards until it hits a delimiter or end of line
  while l:end_index < len(a:line_text) - 1 && match(a:line_text[l:end_index+1], l:delimiter) < 0
    let l:end_index = l:end_index + 1
  endwhile

  let l:fragment = a:line_text[l:start_index : l:end_index]
  let l:index = l:index - l:start_index

  let l:results = []

  let l:name_regex = '\(\u\(\w\|''\)*\.\)*\(\a\|_\)\(\w\|''\)*'
  let l:operator_regex = '\(\u\(\w\|''\)*\.\)*\(\\\|[-!#$%&*+./<=>?@^|~:]\)\+'

  " Perform two passes over the fragment(one for finding a name, and the other
  " for finding an operator). Each pass tries to find a match that has the
  " cursor contained within it.
  for l:regex in [l:name_regex, l:operator_regex]
    let l:remainder = l:fragment
    let l:rindex = l:index
    while 1
      let l:i = match(l:remainder, l:regex)
      if l:i < 0
        break
      endif
      let l:result = matchstr(l:remainder, l:regex)
      let l:end = l:i + len(l:result)
      if l:i <= l:rindex && l:end > l:rindex
        call add(l:results, l:result)
        break
      endif
      let l:remainder = l:remainder[l:end :]
      let l:rindex = l:rindex - l:end
    endwhile
  endfor

  " There can be at most 2 matches(one from each pass). The longest one is the
  " correct one.
  if len(l:results) == 0
    return ''
  elseif len(l:results) == 1
    return l:results[0]
  else
    if len(l:results[0]) > len(l:results[1])
      return l:results[0]
    else
      return l:results[1]
    endif
  endif
endfunction

" Unit Test
" a verbatim copy from vim-hdevtools
function! hoogle#test_extract_identifier()
  let l:tests = [
        \ 'let #foo# = 5',
        \ '#main#',
        \ '1 #+# 1',
        \ '1#+#1',
        \ 'blah #Foo.Bar# blah',
        \ 'blah #Foo.bar# blah',
        \ 'blah #foo#.Bar blah',
        \ 'blah #foo#.bar blah',
        \ 'blah foo#.#Bar blah',
        \ 'blah foo#.#bar blah',
        \ 'blah foo.#bar# blah',
        \ 'blah foo.#Bar# blah',
        \ 'blah #A.B.C.d# blah',
        \ '#foo#+bar',
        \ 'foo+#bar#',
        \ '#Foo#+bar',
        \ 'foo+#Bar#',
        \ '#Prelude..#',
        \ '[#foo#..bar]',
        \ '[foo..#bar#]',
        \ '#Foo.bar#',
        \ '#Foo#*bar',
        \ 'Foo#*#bar',
        \ 'Foo*#bar#',
        \ '#Foo.foo#.bar',
        \ 'Foo.foo#.#bar',
        \ 'Foo.foo.#bar#',
        \ '"a"#++#"b"',
        \ '''a''#<#''b''',
        \ '#Foo.$#',
        \ 'foo.#Foo.$#',
        \ '#-#',
        \ '#/#',
        \ '#\#',
        \ '#@#'
        \ ]
  for l:test in l:tests
    let l:expected = matchstr(l:test, '#\zs.*\ze#')
    let l:input = substitute(l:test, '#', '', 'g')
    let l:start_index = match(l:test, '#') + 1
    let l:end_index = match(l:test, '\%>' . l:start_index . 'c#') - 1
    for l:i in range(l:start_index, l:end_index)
      let l:result = s:extract_identifier(l:input, l:i)
      if l:expected !=# l:result
        call s:print_error("TEST FAILED expected: (" . l:expected . ") got: (" . l:result . ") for column " . l:i . " of: " . l:input)
      endif
    endfor
  endfor
endfunction


function! s:print_error(msg)
  echohl ErrorMsg
  echomsg a:msg
  echohl None
endfunction


function! s:print_warning(msg)
  echohl WarningMsg
  echomsg a:msg
  echohl None
endfunction
