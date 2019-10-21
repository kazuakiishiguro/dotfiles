set nocompatible

" Make backspace behave in a sane manner
set backspace=indent,eol,start

" Switch syntax highlighting on
syntax on

" Security
set modelines=0

" Show line numbers
set number

" Enable file type detection and do language-dependent indenting
filetype plugin indent on

" Enable auto indenting
set autoindent

" Show search matches
set showmatch

" Disable backup files
set nobackup

" Change color scheme
colorscheme desert

" Bind jj to ESC
inoremap <silent> jj <ESC>

" Bind emacs-keybind for insert mode
imap <C-p> <Up>
imap <C-n> <Down>
imap <C-b> <Left>
imap <C-f> <Right>