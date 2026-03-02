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
  if command -v Xorg >/dev/null 2>&1; then
    # set xcape keymap
    source $HOME/.bin/start-xcape.sh
  fi
elif [ -f /etc/arch-release ]; then
  platform='arch'
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
if [[ "$platform" == "osx" ]]; then
  alias l='ls -ltrG'
  alias ls='ls -G'
  alias la='ls -laG'
  alias ll='ls -lG'
else
  alias l='ls -ltr --color=auto'
  alias ls='ls --color=auto'
  alias la='ls -la --color=auto'
  alias ll='ls -l --color=auto'
fi
alias dockerrm='docker rm $(docker ps -aq)'
alias dockerrmi='docker rmi $(docker images -aq)'
alias dockerstop='docker stop $(docker ps -aq)'
alias dockerkill='docker kill $(docker ps -aq)'
alias emacsmin='emacs -nw --no-init-file --no-site-file'
alias emacs='emacs -nw'

# for gpg sign
export GPG_TTY=$(tty)

# Set up fzf key bindings and fuzzy completion
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi
