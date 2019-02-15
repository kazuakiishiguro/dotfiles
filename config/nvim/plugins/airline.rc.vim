let g:airline_theme = 'wombat'
set laststatus=2
let g:airline_powerline_fonts = 1
let g:airline#extensions#branch#enabled = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#taboo#enabled = 1
if !has('nvim')
  let g:airline#extensions#whitespace#mixed_indent_algo = 2 " see :help airline-whitespace@en
endif
let g:airline#extensions#branch#enabled = 0