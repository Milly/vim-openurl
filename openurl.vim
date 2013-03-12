" Vim plugin file - openurl
"
" Last Change:   12 Mar 2013
" Maintainer:    Milly
" Purpose:       Open url or file with default viewer.
" Options:
"   g:openurl_regex        - URL match regex (default empty)
"   g:openurl_dos_path     - Enable DOS path (default: 0)
"   g:openurl_encoding     - Character encoding for URL (default: utf-8)
"   g:no_openurl_highlight - Not define highlight (default: 0)
"=============================================================================

" Define  "{{{1
if exists('g:loaded_openurl')
  finish
endif
scriptencoding utf-8

let s:is_windows = has('win16') || has('win32') || has('win64')
let s:is_cygwin = has('win32unix')
let s:is_mac = !s:is_windows && !s:is_cygwin
      \ && ( has('mac') || has('macunix') || has('gui_macvim') ||
      \      (!isdirectory('/proc') && executable('sw_vers')) )
let s:is_unix = has('unix')

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
let s:MAIL_REGEX = '\<[a-zA-Z][a-zA-Z0-9.+-]\+@\<[a-zA-Z][a-zA-Z0-9-]*\>\%(\.\<[a-zA-Z][a-zA-Z0-9-]*\>\)*\.\%([a-zA-Z]\{2,9}\)\>[.-]\@!'
let s:URL_PATH_REGEX = '\%('.s:URL_CHAR_REGEX.'\|'.s:LPAREN_REGEX.'\%('.s:URL_CHAR_REGEX.'\)*'.s:RPAREN_REGEX.'\)\+'
let s:URL_REGEX = '\<[a-z+-]\+\>://'.s:URL_PATH_REGEX.'\|\%(mailto:\|xmpp://\)\?'.s:MAIL_REGEX
let s:DOS_PATH_REGEX = '\%('.s:DOS_CHAR_REGEX.'\|'.s:LPAREN_REGEX.'\%('.s:DOS_CHAR_REGEX.'\)*'.s:RPAREN_REGEX.'\)\+'
let s:DOS_PATH_REGEX = '\%(^\|\s\@<=\|'.s:LPAREN_REGEX.'\@<=\|\<file:///\)\%(\%([a-zA-Z]:\|\\\)\%([/\\\\]'.s:DOS_PATH_REGEX.'\)\+[/\\\\]\?\|[a-z]:\\\)'

let s:default_openurl_commands = [
      \   { 'enabled': s:is_windows, 'command': 'rundll32', 'filter': 's:WindowsUrlFilter',
      \     'cmdline': 'start rundll32 url.dll,FileProtocolHandler {url}' },
      \   { 'enabled': s:is_cygwin,  'command': 'cygstart', 'filter': 's:CygwinUrlFilter',
      \     'cmdline': 'VIM= VIMRUNTIME= SHELL= TEMP= TMP= HOME=$HOMEPATH cygstart {url}' },
      \   { 'enabled': s:is_mac,     'command': 'open' },
      \   { 'enabled': s:is_unix,    'command': 'gnome-open' },
      \   { 'enabled': s:is_unix,    'command': 'xdg-open' },
      \ ]

if !exists('g:openurl_regex')
  let g:openurl_regex = ''
endif

if !exists('g:openurl_dos_path')
  let g:openurl_dos_path = 0
endif

if !exists('g:openurl_encoding') && s:is_unix
  let s:charset = matchstr(v:lang, '\.\zs.\+$')
  if s:charset | let g:openurl_encoding = s:charset | endif
endif
if !exists('g:openurl_encoding') && (s:is_windows || s:is_cygwin) && executable('chcp')
  let s:codepage = matchstr(system('chcp'), ' \zs\d\+\ze\(\n\|$\)')
  if s:codepage | let g:openurl_encoding = 'cp'.s:codepage | endif
endif
if !exists('g:openurl_encoding')
  let g:openurl_encoding = 'utf-8'
endif

if !exists('g:no_openurl_highlight')
  let g:no_openurl_highlight = 0
endif

let s:SEARCH_URL = 'http://www.google.com/search?q={query}&ie={encoding}'
if !exists('g:openurl_search_url')
  let g:openurl_search_url = s:SEARCH_URL
endif

if !exists('g:openurl_commands')
  let g:openurl_commands = []
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


" Util functions {{{1
if exists('+shellslash')
  function! s:call_noshellslash(func, args)
    let [shellslash, &l:shellslash] = [&l:shellslash, 0]
    try
      return call(a:func, a:args)
    finally
      let &l:shellslash = shellslash
    endtry
  endf
else
  function! s:call_noshellslash(func, args)
    return call(a:func, a:args)
  endf
endif

function! s:shellescape(str)
  let str = substitute(a:str, '[%#<]', '\\\0', 'g')
  return s:call_noshellslash('shellescape', [str])
endf

function! s:encode_uri(str)
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


" Url filters {{{1
function! s:WindowsUrlFilter(url)
  let url = a:url
  let url = substitute(url, '^\(smb:\)\?[/\\]\{2,4}', '\\\\', 'i')
  if 0 == match(url, s:DOS_PATH_REGEX)
    let url = substitute(url, '/', '\\', 'g')
    let url = s:call_noshellslash('fnamemodify', [url, ':p'])
  elseif 0 == match(url, s:MAIL_REGEX)
    let url = 'mailto:' . url
  endif
  return url
endf

function! s:CygwinUrlFilter(url)
  let url = a:url
  let url = substitute(url, '\\', '/', 'g')
  let url = substitute(url, '^\(smb:\)\?/\{2,4}', '//', 'i')
  let url = substitute(url, '^file://\%(localhost\ze/\|/\ze//\)\?', '', 'i')
  return url
endf

function! s:NopFilter(url)
  return url
endf


" Open command  "{{{1
function! s:GetOpenUrlCommand()
  if !exists('s:openurl_command')
    let s:openurl_command = {'enabled': 0}
    let commands = get(g:, 'openurl_commands', [])
    for cmd in empty(commands) ? s:default_openurl_commands : commands
      if get(cmd, 'enabled', 1) && executable(get(cmd, 'command', ''))
        let s:openurl_command = extend({
              \ 'enabled': 1,
              \ 'cmdline': '{command} {url}',
              \ 'filter': 's:NopFilter',
              \ }, cmd)
        break
      endif
    endfor
  endif
  return s:openurl_command
endf

function! s:CreateCommandLine(cmdline, data)
  return substitute(a:cmdline, '{\(\w\+\)}', '\=s:shellescape(get(a:data, submatch(1), ""))', 'g')
endf

function! s:OpenUrl(url)
  let cmd = s:GetOpenUrlCommand()
  if !cmd.enabled
    echom 'openurl: Command not enabled.'
  endif

  let url = a:url
  if has('iconv') && exists('g:openurl_encoding') && 0 < strlen(g:openurl_encoding)
    let url = iconv(url, &encoding, g:openurl_encoding)
  endif
  let url = call(cmd.filter, [url])

  let data = extend({'url': url}, cmd, 'keep')
  silent! exec '!' . s:CreateCommandLine(cmd.cmdline, data)
endf

function! s:ListUrl(ArgLead, CmdLine, CursorPos)
  let l:regdir = '.*'.'/'
  if s:is_windows || s:is_cygwin
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
  let l:query = s:encode_uri(l:query)
  let l:url = substitute(l:url, '{query}', l:query, 'g')
  let l:url = substitute(l:url, '{encoding}', l:encoding, 'g')
  call s:OpenUrl(l:url)
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
