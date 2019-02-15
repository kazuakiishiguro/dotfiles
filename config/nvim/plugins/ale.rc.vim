let g:ale_lint_on_text_changed = 0
let g:ale_sign_error = 'E➤'
let g:ale_sign_warning = 'W➤'
let g:airline#extensions#ale#open_lnum_symbol = '('
let g:airline#extensions#ale#close_lnum_symbol = ')'
let g:ale_echo_msg_format = '[%linter%]%code: %%s'
let g:ale_lint_on_text_changed = 'normal'

let g:ale_linters = {
\   'html': [],
\}

let g:ale_fixers = {
\   'c': ['clang-format'],
\   'cpp': ['clang-format'],
\   'vue': ['prettier', 'eslint'],
\   'javascript': ['prettier', 'eslint'],
\   'typescript': ['prettier', 'eslint'],
\   'json': ['prettier'],
\   'css': ['prettier'],
\   'less': ['prettier'],
\   'scss': ['prettier'],
\   'python': ['autopep8'],
\}