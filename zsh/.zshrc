HISTSIZE=1000
HISTFILESIZE=2000

# arch
arch=`uname -m`

# os
platform='unknown'
if [[ `uname` == 'Darwin' ]]; then
  platform='osx'
elif [[ `uname -a` == *Ubuntu* ]]; then
    platform='debian'
    if _is_command Xorg; then
      # set xcape keymap
      source $HOME/.bin/start-xcape.sh
    fi
fi

# env
export PATH="$PATH:$HOME/.bin"
export PATH="/usr/local/sbin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

autoload -Uz vcs_info
setopt prompt_subst

# git branch
zstyle ':vcs_info:*' formats "%F{green}%c%u(%b)%f"
precmd () { vcs_info }

# comand prompt
PROMPT='%n@%m:%F{cyan}%~%f%F{green}$vcs_info_msg_0_%f$ '

# aliases
alias l='ls -ltrG'
alias ls='ls -G'
alias la='ls -laG'
alias ll='ls -lG'
alias dockerrm='docker rm $(docker ps -aq)'
alias dockerrmi='docker rmi $(docker images -aq)'
alias dockerstop='docker stop $(docker ps -aq)'
alias dockerkill='docker kill $(docker ps -aq)'
alias emacsmin='emacs -nw --no-init-file --no-site-file'
alias emacs='emacs -nw'

# for gpg sign
export GPG_TTY=$(tty)

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)
