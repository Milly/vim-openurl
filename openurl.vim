"*** DON'T REMOVE THIS LINE ***"; new ActiveXObject("WScript.Shell").Run('"'+WScript.Arguments.Item(0)+'"'); /*

" Vim plugin file - openurl
"
" Last Change:   10 February 2010
" Maintainer:    Milly
" Purpose:       Open url or file with default viewer.
" Options:
"   g:openurl_encoding     - Character encoding for URL (default: utf-8)
"   g:no_openurl_highlight - Not define highlight (default: 0)
"=============================================================================
" Define  "{{{1
if exists('g:loaded_openurl')
  finish
endif

let s:URL_REGEX = '\<[a-z+-]\+\>://[-!#%&+,./0-9:;=?@A-Za-z_~]\+'

if !exists('g:openurl_encoding')
  let g:openurl_encoding = 'utf-8'
  if (has('win32') || has('win32unix')) && 0 <= match($LANG, '^ja', 'i')
    let g:openurl_encoding = 'cp932'
  endif
endif

if !exists('g:no_openurl_highlight')
  let g:no_openurl_highlight = 0
endif


" Syntax  "{{{1
if has('syntax') && !g:no_openurl_highlight

  function! s:HighlightUrl()
    if &buftype == ''
      exec "syntax match ClickableUrl '" . s:URL_REGEX . "' display containedin=ALL"
      hi def link ClickableUrl Underlined
    endif
  endf

  augroup highlight_url
    au!
    au BufNew,BufRead,FileType,ColorScheme * call s:HighlightUrl()
  augroup END

endif


" Open command  "{{{1
let s:wsh_script = expand('<sfile>:p')

function! s:OpenUrl(url)
  let l:url = a:url
  if has('iconv') && exists('g:openurl_encoding') && 0 < strlen(g:openurl_encoding)
    let l:url = iconv(l:url, &encoding, g:openurl_encoding)
  endif
  if has('win32') && executable('wscript')
    let l:url = substitute(l:url, '^smb://', '\\\\', '')
    silent! exec '!start wscript //E:JScript "' . s:wsh_script . '" "' . l:url . '"'
  elseif has('win32unix') && executable('cygstart')
    let l:url = substitute(l:url, '^file://\(localhost/\@=\)\?', '', '')
    silent! exec "!cygstart '" . l:url . "'"
  elseif has('mac') && executable('open')
    silent! exec "!open '" . l:url . "'"
  elseif has('unix') && executable('gnome-open')
    silent! exec "!gnome-open '" . l:url . "'"
  elseif has('unix') && executable('xdg-open')
    silent! exec "!xdg-open '" . l:url . "'"
  endif
endf

command! -nargs=1 -complete=file Open call <SID>OpenUrl('<args>')


" Mouse mapping  "{{{1
if has('mouse')

  function! s:OpenUrlOnCursor()
    let l:cursor = col('.') - 1
    let l:line = getline('.')
    let l:pos = 0
    while 1
      let l:pos = match(l:line, s:URL_REGEX, l:pos)
      let l:url = matchstr(l:line, s:URL_REGEX, l:pos)
      if l:pos < 0 || l:cursor < l:pos
        break
      endif
      let l:pos = l:pos + strlen(l:url)
      if l:cursor < l:pos
        call s:OpenUrl(l:url)
        break
      endif
    endw
  endf

  noremap <silent> <Plug>(openurl) <ESC>:call <SID>OpenUrlOnCursor()<CR>
  silent! map <2-LeftMouse> <Plug>(openurl)

endif


" Done  "{{{1
let g:loaded_openurl=1

" vim: foldmethod=marker:
"*** DON'T REMOVE THIS LINE ***"; */