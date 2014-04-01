if exists('b:did_ftplugin_hoogle') && b:did_ftplugin_hoogle
  finish
endif
let b:did_ftplugin_hoogle = 1

if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= ' | '
else
  let b:undo_ftplugin = ''
endif

command! -buffer -nargs=? Hoogle call hoogle#hoogle(<q-args>)

let b:undo_ftplugin .= join(map([
      \ 'HsimportModule',
      \ 'HsimportSymbol'
      \ ], '"delcommand " . v:val'), ' | ')
let b:undo_ftplugin .= ' | unlet b:did_ftplugin_hoogle'
