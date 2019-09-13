HISTSIZE=1000
HISTFILESIZE=2000

# env
export PATH="$PATH:$HOME/.bin"
export PATH="/usr/local/sbin:$PATH"

# lang
if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
  export LC_ALL="en_US.UTF-8"
fi

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

# bash-complete
HOMEBREW_PREFIX=$(brew --prefix)
if type brew &>/dev/null; then
  if [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
    source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
  else
    for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
      [[ -r "$COMPLETION" ]] && source "$COMPLETION"
    done
  fi
fi

# emoji ψ(｀∇´)ψ
function _dirt() {
  echo -e "\U1F918"
}

# git branch
function _git_branch () {
  # Get current Git branch
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

# comand prompt
export PS1="\$(_dirt)  \[\e[36m\]\W \[\e[32m\]\$(_git_branch) \[\e[0m\] \$ "

# aliases
alias ls='gls --color=auto'
alias ll='ls -al'
alias t='tmux'
alias ta='tmux attach'
alias tks='tmux kill-server'
alias htop='sudo htop'
alias g='git'
alias diff='icdiff'

alias emacsmin='emacs -nw --no-init-file --no-site-file'
alias emacs='emacs -nw'


# fzf
if which fzf > /dev/null 2>&1; then
  [ -f ~/.fzf.bash ] && source ~/.fzf.bash
else
  brew install fzf
  $(brew --prefix)/opt/fzf/install
  source ~/.bashrc
fi

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

# go
if [ -x "`which go`" ]; then
  export GOPATH=$HOME/.go
  export PATH=$PATH:$GOPATH/bin
fi

# rustc
if [ -e "$HOME/.cargo" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

# homeshick
source "$HOME/.homesick/repos/homeshick/homeshick.sh"
