HISTSIZE=1000
HISTFILESIZE=2000

# dircolors
export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"
eval $(dircolors ~/.dircolors/dircolors.ansi-dark)

# comand prompt
export PS1="\u@\h:~\\$ "

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
