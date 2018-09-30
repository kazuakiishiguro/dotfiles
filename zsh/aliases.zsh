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

# -- Chrome setting -----------------------------------------------------------
# [C] explained: http://www.commandlinefu.com/commands/view/402/exclude-grep-from-your-grepped-output-of-ps-alias-included-in-description
alias chromekill="ps ux | grep '[C]hrome Helper --type=renderer' | grep -v extension-process | tr -s ' ' | cut -d ' ' -f2 | xargs kill"

alias chrome="/Applications/Google\\ \\Chrome.app/Contents/MacOS/Google\\ \\Chrome"
alias canary="/Applications/Google\\ Chrome\\ Canary.app/Contents/MacOS/Google\\ Chrome\\ Canary"

alias pcat='pygmentize -f terminal256 -O style=native -g'

# -- Update setting -----------------------------------------------------------
alias update!="cd && ${updateCmd} && cd - > null"