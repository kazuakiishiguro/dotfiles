HISTSIZE=1000
HISTFILESIZE=2000

# dircolors
export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"
eval $(dircolors ~/.dircolors/dircolors.ansi-dark)

# User specific environment and startup programs

export PS1="\u@\h:~\\$ "

# aliases
alias ls='gls --color=auto'
alias ll='ls -al'

# nvm path setting
export NVM_DIR=~/.nvm
source $(brew --prefix nvm)/nvm.sh

# rustc path setting
export PATH=${HOME}/.cargo/bin:${PATH}
