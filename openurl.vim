"*** DON'T REMOVE THIS LINE ***";s=new ActiveXObject("WScript.Shell");e=s.Environment("PROCESS");e.Item('P')='%';s.Run('"'+WScript.Arguments.Item(0).replace(/%/g,'%P%')+'"'); /*

" Vim plugin file - openurl
"
" Last Change:   15 October 2010
" Maintainer:    Milly
" Purpose:       Open url or file with default viewer.
" Options:
"   g:openurl_regex        - URL match regex (default empty)
"   g:openurl_dos_path     - Enable DOS path (default: 1)
"   g:openurl_encoding     - Character encoding for URL (default: utf-8)
"   g:no_openurl_highlight - Not define highlight (default: 0)
"=============================================================================
" NOTE: Cannot include WScript's comment-end in this script. (replace to '*'.'/')

" Define  "{{{1
if exists('g:loaded_openurl')
  finish
endif

if has('multi_byte')
  let s:URL_CHAR_REGEX = '[-!#%&+,./\\:;=?$@_~[:alnum:]]\|[^[:print:][:cntrl:]]'
  let s:DOS_CHAR_REGEX = '[-!#%&+,.;=$@_~'."'".'`[:alnum:]]\|[^[:print:][:cntrl:]]\| '
  let s:LPAREN_REGEX = '[({\[（［｛＜「【『≪〈《〔]'
  let s:RPAREN_REGEX = '[〕》〉≫』】」＞｝］）\]})]'
else
  let s:URL_CHAR_REGEX = '[-!#%&+,./\\:;=?$@_~[:alnum:]]'
  let s:DOS_CHAR_REGEX = '[-!#%&+,.;=$@_~'."'".'`[:alnum:] ]'
  let s:LPAREN_REGEX = '[({\[]'
  let s:RPAREN_REGEX = '[\]})]'
endif
let s:URL_PATH_REGEX = '\('.s:URL_CHAR_REGEX.'\|'.s:LPAREN_REGEX.'\('.s:URL_CHAR_REGEX.'\)*'.s:RPAREN_REGEX.'\)\+'
let s:URL_REGEX = '\<\<[a-z+-]\+\>://'.s:URL_PATH_REGEX
let s:DOS_PATH_REGEX = '\('.s:DOS_CHAR_REGEX.'\|'.s:LPAREN_REGEX.'\('.s:DOS_CHAR_REGEX.'\)*'.s:RPAREN_REGEX.'\)\+'
let s:DOS_PATH_REGEX = '\(^\|\s\@<=\|'.s:LPAREN_REGEX.'\@<=\|\<file:///\)\(\([a-z]:\|\\\)\([/\\\\]'.s:DOS_PATH_REGEX.'\)\+[/\\\\]\?\|[a-z]:\\\)'

if !exists('g:openurl_regex')
  let g:openurl_regex = ''
endif

if !exists('g:openurl_dos_path')
  let g:openurl_dos_path = 1
endif

if !exists('g:openurl_encoding')
  let g:openurl_encoding = 'utf-8'
  if (has('win32') || has('win32unix')) && 0 <= match($LANG, '^ja', 'i')
    let g:openurl_encoding = 'cp932'
  endif
endif

if !exists('g:no_openurl_highlight')
  let g:no_openurl_highlight = 0
endif

let s:SEARCH_URL = 'http://www.google.com/search?q={query}&ie={encoding}'
if !exists('g:openurl_search_url')
  let g:openurl_search_url = s:SEARCH_URL
endif


" Get url regex  "{{{1
function! s:GetUrlRegex()
  if exists('g:openurl_regex') && g:openurl_regex != ''
    let l:regex = g:openurl_regex
  else
    let l:regex = s:URL_REGEX
  endif
  if exists('g:openurl_dos_path') && g:openurl_dos_path
    let l:regex = s:DOS_PATH_REGEX.'\|'.l:regex
  endif
  return l:regex
endf


" Syntax  "{{{1
if has('syntax') && !g:no_openurl_highlight

  function! s:HighlightUrl()
    if &buftype == ''
      silent! syntax clear ClickableUrl
      exec "syntax match ClickableUrl '" . s:GetUrlRegex() . "' display containedin=ALL"
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
    let l:url = substitute(l:url, '^\(smb:\)\?[/\\]\{2,4}', '\\\\', 'i')
    let l:url = substitute(l:url, '[!%]', '\\&', 'g')
    silent! exec '!start wscript //E:JScript "' . s:wsh_script . '" "' . l:url . '"'
  elseif has('win32unix') && executable('cygstart')
    let l:url = substitute(l:url, '^file://\(localhost/\@=\)\?', '', 'i')
    let l:url = substitute(l:url, '^/\([a-z]\):\(/\@=\|$\)', '/cygdrive/\l\1', 'i')
    let l:url = substitute(l:url, '[\\!%]', '\\&', 'g')
    silent! exec "!cygstart '" . l:url . "'"
  elseif has('mac') && executable('open')
    let l:url = substitute(l:url, '[\\!%]', '\\&', 'g')
    silent! exec "!open '" . l:url . "'"
  elseif has('unix') && executable('gnome-open')
    let l:url = substitute(l:url, '[\\!%]', '\\&', 'g')
    silent! exec "!gnome-open '" . l:url . "'"
  elseif has('unix') && executable('xdg-open')
    let l:url = substitute(l:url, '[\\!%]', '\\&', 'g')
    silent! exec "!xdg-open '" . l:url . "'"
  else
    echom 'openurl: Command not found to open url.'
  endif
endf

function! s:ListUrl(ArgLead, CmdLine, CursorPos)
  let l:regdir = '.*'.'/'
  if has('win32') || has('win32unix')
    let l:regdir = '.*'.'/\|[A-Za-z]:'
  endif
  let l:m = matchlist(a:ArgLead, '^\(file://\)\?\(' . l:regdir . '\)\?\([^/]*\)$')
  if !empty(l:m) && !empty(l:m[0])
    if !empty(l:m[1])
      if !empty(l:m[2])
        return substitute(globpath(l:m[2], l:m[3] . '*'), '^\|\n', '&file://', 'g')
      endif
      return "file://./\nfile://../\nfile:///"
    else
      if empty(l:m[2])
        let l:res = substitute(globpath('.', l:m[3] . '*'), '\(^\|\n\)\./', '\1', 'g')
      else
        let l:res = globpath(l:m[2], l:m[3] . '*')
      endif
      if !empty(l:res)
        return l:res
      end
    endif
  endif
  return "file://\nftp://\nhttp://\nhttps://\nsmb://"
endf

command! -nargs=1 -complete=custom,<SID>ListUrl Open call <SID>OpenUrl('<args>')


" Search command  "{{{1
function! s:Search(query)
  let l:url = s:SEARCH_URL
  let l:query = a:query
  let l:encoding = &encoding
  if exists('g:openurl_search_url') && 0 < len(g:openurl_search_url)
    let l:url = g:openurl_search_url
  endif
  if has('iconv') && exists('g:openurl_encoding') && 0 < strlen(g:openurl_encoding)
    let l:encoding = g:openurl_encoding
    let l:query = iconv(l:query, &encoding, g:openurl_encoding)
  endif
  let l:query = s:UrlEncode(l:query)
  let l:url = substitute(l:url, '{query}', l:query, 'g')
  let l:url = substitute(l:url, '{encoding}', l:encoding, 'g')
  call s:OpenUrl(l:url)
endf

function! s:UrlEncode(str)
  let l:res = []
  let l:idx = len(a:str)
  while 0 < l:idx
    let l:idx = l:idx - 1
    let l:c = a:str[l:idx]
    if 0 <= match(l:c, "[^0-9a-zA-Z!'()*._~-]")
      let l:c = printf('%%%02X', char2nr(l:c))
    endif
    call add(l:res, l:c)
  endw
  return join(reverse(l:res), '')
endf

command! -nargs=1 -complete=tag Search call <SID>Search('<args>')


" Cursor mapping  "{{{1
function! s:GetCursorUrl()
  let l:cursor = col('.')
  let l:line = getline('.')
  let l:pos = 0
  let l:url_regex = s:GetUrlRegex()
  while 1
    let l:pos = match(l:line, l:url_regex, l:pos)
    let l:url = matchstr(l:line, l:url_regex, l:pos)
    if l:pos < 0 || l:cursor <= l:pos
      return ''
    endif
    let l:pos = l:pos + strlen(l:url)
    if l:cursor <= l:pos
      return l:url
    endif
  endw
endf

function! s:OpenUrlOnCursor()
  let l:tagjump = 0 < a:0 && a:1
  let l:url = s:GetCursorUrl()
  if 0 < len(l:url)
    call s:OpenUrl(l:url)
    return 1
  endif
endf

nnoremap <silent> <Plug>(openurl) :call <SID>OpenUrlOnCursor()<CR>
nnoremap <silent> <Plug>(openurl_or_tag) :<C-U>if !<SID>OpenUrlOnCursor()<CR>exec v:count.'tag '.expand('<cword>')<CR>endif<CR>

silent! nmap <C-Return> <Plug>(openurl)
silent! nmap <C-]> <Plug>(openurl_or_tag)
if has('mouse')
  silent! map <2-LeftMouse> <Plug>(openurl)
  silent! map <C-LeftMouse> <Plug>(openurl_or_tag)
endif


" Done  "{{{1
let g:loaded_openurl=1

" vim: foldmethod=marker:
"*** DON'T REMOVE THIS LINE ***"; */
