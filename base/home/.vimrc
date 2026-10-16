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

" Open splits to the right and below
set splitright
set splitbelow

" Clear search highlight with double Esc
nmap <ESC><ESC> ;nohlsearch<CR><ESC>

" Do not continue comments on new lines
autocmd FileType * setlocal formatoptions-=ro

" Share yank with the system clipboard
set clipboard=unnamed,autoselect

" Strip trailing whitespace on save
function! s:remove_dust()
    let cursor = getpos(".")
    if &filetype == "markdown"
      " In markdown keep at most two trailing spaces (hard line break)
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

" Create missing directories on save
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

" Clear search highlight with double Esc
set hlsearch
noremap <Esc><Esc> :nohlsearch<CR><Esc>

" Swap colon and semicolon
noremap ; :

" Do not wrap search around the end of the file
set nowrapscan

" Use very magic regex for search
nnoremap / /\v

" Turn paste off when leaving insert mode
autocmd InsertLeave * set nopaste

" Do not create undo files
set noundofile

" Indent
set autoindent
set smartindent
set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4
if has("autocmd")
    filetype indent on
    " To disable indent for a filetype:
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

" Allow pattern matching on files up to 1GB
set maxmempattern=1073741824

colorscheme iceberg
set imdisable        " IME off
set antialias        " Antialiasing
set number           " Show line numbers
set nobackup         " No backup files
set visualbell t_vb= " No beep
set textwidth=0      " Never auto-wrap long lines
set nowrapscan       " Do not wrap search around the end of the file
set colorcolumn=80
set background=dark


" Transparent background for normal text
highlight Normal ctermbg=NONE guibg=NONE

" Transparent background for gutter columns
highlight LineNr ctermbg=NONE guibg=NONE
highlight SignColumn ctermbg=NONE guibg=NONE
highlight FoldColumn ctermbg=NONE guibg=NONE
highlight EndOfBuffer ctermbg=NONE guibg=NONE
highlight ColorColumn ctermbg=NONE guibg=NONE
