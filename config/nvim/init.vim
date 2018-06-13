" -- General ------------------------------------------------------------------
set fenc=utf-8
set autoread                          " detect when a file is changed
set history=1000                      " change history to 1000
set textwidth=120                     " set sext width

" -- Appearance ---------------------------------------------------------------
set number                             " show line numbers
set hidden                             " current buffer can be put into background
set showcmd                            " show incomplete commands
set autoindent                         " automatically set indent of new line
set clipboard+=unnamed
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

" -- Searching ----------------------------------------------------------------
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
