"--------------------------
" mark - dein
"--------------------------

if &compatible
  set nocompatible               " Be iMproved
endif

" Required:
set runtimepath+=~/.cache/dein/repos/github.com/Shougo/dein.vim

" Required:
call dein#begin('~/.cache/dein')

" Let dein manage dein
" Required:
call dein#add('~/.cache/dein/repos/github.com/Shougo/dein.vim')

" Add or remove your plugins here like this:
"call dein#add('Shougo/neosnippet.vim')
"call dein#add('Shougo/neosnippet-snippets')
call dein#add('cocopon/iceberg.vim')

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
" mark - basic settings
"--------------------------

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

"検索をファイルの先頭へループしない
set nowrapscan

"正規表現をvery magicに
nnoremap / /\v

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

colorscheme iceberg
set imdisable        "IME OFF
set antialias        "アンチエイリアス
set number           "行番号表示
set nobackup         "バックアップなし
set visualbell t_vb= "ビープ音なし
set textwidth=0      "複数行にまたぐコードを改行しないように
set nowrapscan       " 検索をファイルの先頭へループしない
set colorcolumn=80
set background=dark
