HISTSIZE=1000
HISTFILESIZE=2000

# dircolors
export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"

LS_COLORS="di=01;36"
export LS_COLORS

if [ -f "$HOME/.dircolors" ]; then
  if type dircolors > /dev/null 2>&1; then
    eval $(dircolors $HOME/.dircolors/dircolors.ansi-dark)
  elif type gdircolors > /dev/null 2>&1; then
    eval $(gdircolors $HOME/.dircolors/dircolors.ansi-dark)
  fi
fi

# add line for prompt
function add_line {
  if [[ -z "${PS1_NEWLINE_LOGIN}" ]]; then
    PS1_NEWLINE_LOGIN=true
  else
    printf '\n'
  fi
}
PROMPT_COMMAND='add_line'

# emoji ψ(｀∇´)ψ
function _dirt() {
  echo -e "\U1F918"
}

# comand prompt
export PS1="$(_dirt)  \[\e[36m\]\W \[\e[0m\] \$ "

# aliases
alias ls='gls --color=auto'
alias ll='ls -al'

# nvm
if [ -e "$HOME/bin" ];then
  export PATH="$HOME/bin:./node_modules/.bin:$PATH"
fi

if [ -e "$HOME/.nvm" ]; then
  export NVM_DIR="$HOME/.nvm"
  if [ -e "/usr/local/opt/nvm/nvm.sh" ]; then
    . "/usr/local/opt/nvm/nvm.sh"
  elif [ -e "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
  fi
fi

# rustc
if [ -e "$HOME/.cargo" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi
