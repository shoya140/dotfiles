"--------------------------
" mark - dein
"--------------------------

if &compatible
  set nocompatible               " Be iMproved
endif

" Required:
set runtimepath+=/Users/shoya/.cache/dein/repos/github.com/Shougo/dein.vim

" Required:
call dein#begin('/Users/shoya/.cache/dein')

" Let dein manage dein
" Required:
call dein#add('/Users/shoya/.cache/dein/repos/github.com/Shougo/dein.vim')

" Add or remove your plugins here like this:
"call dein#add('Shougo/neosnippet.vim')
"call dein#add('Shougo/neosnippet-snippets')

" Required:
call dein#end()

" Required:
filetype plugin indent on
syntax enable

" If you want to install not installed plugins on startup.
if dein#check_install()
  call dein#install()
endif

"--------------------------
" mark - plugins - unite
"--------------------------

" 入力モードで開始する
"let g:unite_enable_start_insert=1
" バッファ一覧
"nnoremap <C-B> :<C-u>Unite buffer<CR>
" ファイル一覧
nnoremap <C-U> :<C-u>UniteWithBufferDir -buffer-name=files file<CR>
" レジスタ一覧
"nnoremap <C-R> :<C-u>Unite -buffer-name=register register<CR>
" 最近使用したファイル一覧
nnoremap <C-H> :<C-u>Unite file_mru<CR>
" 常用セット
"nnoremap <silent> ,uu :<C-u>Unite buffer file_mru<CR>
" 全部乗せ
"nnoremap <silent> ,ua :<C-u>UniteWithBufferDir -buffer-name=files buffer file_mru bookmark file<CR>
" ウィンドウを分割して開く
"au FileType unite nnoremap <silent> <buffer> <expr> <C-j> unite#do_action('split')
"au FileType unite inoremap <silent> <buffer> <expr> <C-j> unite#do_action('split')
" ウィンドウを縦に分割して開く
"au FileType unite nnoremap <silent> <buffer> <expr> <C-l> unite#do_action('vsplit')
"au FileType unite inoremap <silent> <buffer> <expr> <C-l> unite#do_action('vsplit')
" ESCキーを2回押すと終了する
"au FileType unite nnoremap <silent> <buffer> <ESC><ESC> q
"au FileType unite inoremap <silent> <buffer> <ESC><ESC> <ESC>q

"--------------------------
" mark - plugins - vim-quickrun
"--------------------------

let g:quickrun_config={'*': {'split': 'vertical'}}

"--------------------------
" mark - plugins - nerdtree
"--------------------------

nnoremap <C-T> :NERDTreeToggle<CR>
let NERDTreeWinSize=20
let NERDTreeShowHidden=1

"--------------------------
" mark - plugins - neocomplcache
"--------------------------

" Disable AutoComplPop.
let g:acp_enableAtStartup = 0
" Use neocomplcache.
let g:neocomplcache_enable_at_startup = 1
" Use smartcase.
let g:neocomplcache_enable_smart_case = 1
" Set minimum syntax keyword length.
let g:neocomplcache_min_syntax_length = 3
let g:neocomplcache_lock_buffer_name_pattern = '\*ku\*'

" Enable heavy features.
" Use camel case completion.
"let g:neocomplcache_enable_camel_case_completion = 1
" Use underbar completion.
"let g:neocomplcache_enable_underbar_completion = 1

" Define dictionary.
let g:neocomplcache_dictionary_filetype_lists = {
    \ 'default' : '',
    \ 'vimshell' : $HOME.'/.vimshell_hist',
    \ 'scheme' : $HOME.'/.gosh_completions'
    \ }

" Define keyword.
if !exists('g:neocomplcache_keyword_patterns')
    let g:neocomplcache_keyword_patterns = {}
endif
let g:neocomplcache_keyword_patterns['default'] = '\h\w*'

" Plugin key-mappings.
inoremap <expr><C-g>     neocomplcache#undo_completion()
inoremap <expr><C-l>     neocomplcache#complete_common_string()

" Recommended key-mappings.
" <CR>: close popup and save indent.
inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
function! s:my_cr_function()
  return neocomplcache#smart_close_popup() . "\<CR>"
  " For no inserting <CR> key.
  "return pumvisible() ? neocomplcache#close_popup() : "\<CR>"
endfunction
" <TAB>: completion.
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
" <C-h>, <BS>: close popup and delete backword char.
inoremap <expr><C-h> neocomplcache#smart_close_popup()."\<C-h>"
inoremap <expr><BS> neocomplcache#smart_close_popup()."\<C-h>"
inoremap <expr><C-y>  neocomplcache#close_popup()
inoremap <expr><C-e>  neocomplcache#cancel_popup()
" Close popup by <Space>.
"inoremap <expr><Space> pumvisible() ? neocomplcache#close_popup() : "\<Space>"

" For cursor moving in insert mode(Not recommended)
inoremap <expr><Left>  neocomplcache#close_popup() . "\<Left>"
inoremap <expr><Right> neocomplcache#close_popup() . "\<Right>"
inoremap <expr><Up>    neocomplcache#close_popup() . "\<Up>"
inoremap <expr><Down>  neocomplcache#close_popup() . "\<Down>"
" Or set this.
"let g:neocomplcache_enable_cursor_hold_i = 1
" Or set this.
"let g:neocomplcache_enable_insert_char_pre = 1

" AutoComplPop like behavior.
"let g:neocomplcache_enable_auto_select = 1

" Shell like behavior(not recommended).
"set completeopt+=longest
"let g:neocomplcache_enable_auto_select = 1
"let g:neocomplcache_disable_auto_complete = 1
"inoremap <expr><TAB>  pumvisible() ? "\<Down>" : "\<C-x>\<C-u>"

" Enable omni completion.
autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags

" Enable heavy omni completion.
if !exists('g:neocomplcache_force_omni_patterns')
  let g:neocomplcache_force_omni_patterns = {}
endif
let g:neocomplcache_force_omni_patterns.php = '[^. \t]->\h\w*\|\h\w*::'
let g:neocomplcache_force_omni_patterns.c = '[^.[:digit:] *\t]\%(\.\|->\)'
let g:neocomplcache_force_omni_patterns.cpp = '[^.[:digit:] *\t]\%(\.\|->\)\|\h\w*::'

" For perlomni.vim setting.
" https://github.com/c9s/perlomni.vim
let g:neocomplcache_force_omni_patterns.perl = '\h\w*->\h\w*\|\h\w*::'

" 補完候補が表示されている場合は確定。そうでない場合は改行
inoremap <expr><CR>  pumvisible() ? neocomplcache#close_popup() : "<CR>"

"--------------------------
" mark - basic settings
"--------------------------

".un~ファイルを作成しない
set noundofile

"ウインドウ分割を右と下に
set splitright
set splitbelow

"Escの2回押しでハイライト消去
nmap <ESC><ESC> ;nohlsearch<CR><ESC>

"改行で勝手にコメントが入らないように
autocmd FileType * setlocal formatoptions-=ro

"ヤンクとクリップボードの連携
set clipboard=unnamed,autoselect

"保存時に無駄な文字を消す
function! s:remove_dust()
    let cursor = getpos(".")
    if &filetype == "markdown"
      "マークダウンで行末にspaceが2つ以上ある場合は2まで切り詰める
      %s/\v(\s{2})?(\s+)?$/\1/e
      match Underlined /\s\{2}$/
    else
      %s/\s\+$//ge
      %s/\t/    /ge
    endif
    call setpos(".", cursor)
    unlet cursor
endfunction
au BufWritePre * call <SID>remove_dust()

"ディレクトリの自動作成
augroup vimrc-auto-mkdir
    autocmd!
    autocmd BufWritePre * call s:auto_mkdir(expand('<afile>:p:h'), v:cmdbang)
    function! s:auto_mkdir(dir, force)
        if !isdirectory(a:dir) && (a:force ||
            \ input(printf('"%s" does not exist. Create? [y/N]', a:dir)) =~? '^y\%[es]$')
            call mkdir(iconv(a:dir, &encoding, &termencoding), 'p')
        endif
    endfunction
augroup END

"検索結果のハイライトをESC連打で消す
set hlsearch
noremap <Esc><Esc> :nohlsearch<CR><Esc>

"コロンセミコロン入れ変え
noremap ; :
"noremap : ;

"検索をファイルの先頭へループしない
set nowrapscan

"正規表現をvery magicに
nnoremap / /\v

" avoiding to stop cursor at the end or the start of the line
" set ww=b,s,h,l,~,<,>,[,]

" insert modeを抜けるときにauto indentをoffに
autocmd InsertLeave * set nopaste

".unファイルを作成しない
set noundofile

"インデント
set autoindent
set smartindent
set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4
if has("autocmd")
    filetype indent on
    " 無効にしたい場合
    " autocmd FileType html filetype indent off
    autocmd FileType apache     setlocal sw=4 sts=4 ts=4 et
    autocmd FileType aspvbs     setlocal sw=4 sts=4 ts=4 et
    autocmd FileType c          setlocal sw=4 sts=4 ts=4 et
    autocmd FileType coffee     setlocal sw=2 sts=2 ts=2 et
    autocmd FileType conf       setlocal sw=4 sts=4 ts=4 et
    autocmd FileType cpp        setlocal sw=4 sts=4 ts=4 et
    autocmd FileType cs         setlocal sw=4 sts=4 ts=4 et
    autocmd FileType css        setlocal sw=4 sts=4 ts=4 et
    autocmd FileType diff       setlocal sw=4 sts=4 ts=4 et
    autocmd FileType eruby      setlocal sw=2 sts=2 ts=2 et
    autocmd FileType haml       setlocal sw=2 sts=2 ts=2 et
    autocmd FileType html       setlocal sw=2 sts=2 ts=2 et
    autocmd FileType java       setlocal sw=4 sts=4 ts=4 et
    autocmd FileType javascript setlocal sw=2 sts=2 ts=2 et
    autocmd FileType less,sass  setlocal sw=2 sts=2 ts=2 et
    autocmd FileType lisp       setlocal sw=2 sts=2 ts=2 et
    autocmd FileType markdown   setlocal sw=4 sts=4 ts=4 et
    autocmd FileType perl       setlocal sw=4 sts=4 ts=4 et
    autocmd FileType php        setlocal sw=4 sts=4 ts=4 et
    autocmd FileType python     setlocal sw=2 sts=2 ts=2 et
    autocmd FileType ruby       setlocal sw=2 sts=2 ts=2 et
    autocmd FileType gitcommit  setlocal sw=2 sts=2 ts=2 et
    autocmd FileType scala      setlocal sw=2 sts=2 ts=2 et
    autocmd FileType scss       setlocal sw=2 sts=2 ts=2 et
    autocmd FileType sh         setlocal sw=4 sts=4 ts=4 et
    autocmd FileType sql        setlocal sw=4 sts=4 ts=4 et
    autocmd FileType vb         setlocal sw=4 sts=4 ts=4 et
    autocmd FileType vim        setlocal sw=2 sts=2 ts=2 et
    autocmd FileType wsh        setlocal sw=4 sts=4 ts=4 et
    autocmd FileType xhtml      setlocal sw=4 sts=4 ts=4 et
    autocmd FileType xml        setlocal sw=4 sts=4 ts=4 et
    autocmd FileType yaml       setlocal sw=2 sts=2 ts=2 et
    autocmd FileType zsh        setlocal sw=4 sts=4 ts=4 et
  endif

set imdisable        "IME OFF
set antialias        "アンチエイリアス
set number           "行番号表示
set nobackup         "バックアップなし
set visualbell t_vb= "ビープ音なし
set textwidth=0      "複数行にまたぐコードを改行しないように
set nowrapscan       " 検索をファイルの先頭へループしない
set colorcolumn=80
