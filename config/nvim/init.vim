" -- General ------------------------------------------------------------------
set encoding=utf-8
scriptencoding utf-8
set autoread                          " detect when a file is changed
set history=1000                      " change history to 1000
set textwidth=120                     " set text width

" -- Appearance ---------------------------------------------------------------
set number                             " show line numbers
set hidden                             " current buffer can be put into background
set showcmd                            " show incomplete commands
set autoindent                         " automatically set indent of new line
set clipboard+=unnamed                 " set shared clipboard
set scrolloff=5                        " lines of text around cursor
set virtualedit=onemore
set smartindent
set laststatus=2
set wildmode=list:longest
set listchars=tab:>-,trail:-,eol:$
set expandtab
set tabstop=2
set shiftwidth=2
noremap j gj
noremap k gk
nnoremap <CR> G
nnoremap <BS> gg

" -- Custom Mappings ----------------------------------------------------------
let mapleader = "\<Space>"             " set a map leader for more key combos
nnoremap <Leader>w :w<CR>              " shortcut to save
" let g:airline_powerline_fonts = 1      " Airline font setting
" set laststatus=2                       " status setting
" let g:airline_theme = 'molokai'        " color scheme

" -- Searching ---------------------------------------------------------------
set incsearch                          " incremental searching
set showmatch                          " show pairs match
set hlsearch                           " highlight search results
set smartcase                          " smart case ignore
set ignorecase                         " ignore case letters

" -- error bells --------------------------------------------------------------
set noerrorbells
set visualbell

" -- Colorscheme --------------------------------------------------------------
syntax enable                          " enable the syntax highlight
set background=dark                    " set a dark background
set t_Co=256                           " 256 colors for the terminal

" -- Parenthesis completion ---------------------------------------------------
inoremap { {}<Left>
inoremap {<Enter> {}<Left><CR><ESC><S-o>
inoremap ( ()<ESC>i
inoremap (<Enter> ()<Left><CR><ESC><S-o>

" -- Disable cursor key for str8 vimmer!! -------------------------------------
nnoremap <up> <nop>
nnoremap <down> <nop>
nnoremap <left> <nop>
nnoremap <right> <nop>
inoremap <up> <nop>
inoremap <down> <nop>
inoremap <left> <nop>
inoremap <right> <nop>

" -- NeoBundle Setting --------------------------------------------------------

"dein Scripts-----------------------------
let s:dein_dir = expand('~/.cache/dein')
let s:dein_repo_dir = s:dein_dir . '/repos/github.com/Shougo/dein.vim'

if &compatible
  set nocompatible
endif

if &runtimepath !~# '/dein.vim'
  if !isdirectory(s:dein_repo_dir)
    execute '!git clone https://github.com/Shougo/dein.vim' s:dein_repo_dir
  endif
  execute 'set runtimepath^=' . fnamemodify(s:dein_repo_dir, ':p')
endif

if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)

  let g:rc_dir    = expand("~/.config/nvim/")
  let s:dein      = g:rc_dir . '/dein.toml'
  let s:dein_lazy      = g:rc_dir . '/dein_lazy.toml'

  call dein#load_toml(s:dein,           {'lazy': 0})
  call dein#load_toml(s:dein_lazy,      {'lazy': 1})

  call dein#end()
  call dein#save_state()
endif

filetype plugin indent on
syntax enable

if dein#check_install()
  call dein#install()
endif

" End dein Scripts-------------------------