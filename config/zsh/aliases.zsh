# -- Reaload zsh config -------------------------------------------------------
alias reload!='RELOAD=1 source ~/.zshrc'

# -- Alias setting ------------------------------------------------------------
if ls --color > /dev/null 2>&1; then  # GNU `ls`
  colorflag="--color"
  updateCmd=".dotfiles/bin/apt"
else                                  # macOS `ls`
  colorflag="-G"
  updateCmd="brew update"
fi

# -- Filesystem setting -------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....="cd ../../.."
alias .....="cd ../../../.."

alias l="ls -lah ${colorflag}"
alias la="ls -AF ${colorflag}"
alias ll="ls -lFh ${colorflag}"
alias lld="ls -l | grep ^d"
alias rmf="rm -rf"

# -- NeoVim setting -----------------------------------------------------------
alias vim="nvim"
alias vi="nvim"

# -- Update setting -----------------------------------------------------------
alias update!="cd && ${updateCmd} && cd - > /dev/null"

# -- ping setting -------------------------------------------------------------
alias p="ping -c 3 google.com"

# -- tmux aliases -------------------------------------------------------------
alias ta='tmux attach'
alias tls='tmux ls'
alias tat='tmux attach -t'
alias tns='tmux new-session -s'
alias tks='tmux kill-server'