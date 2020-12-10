HISTSIZE=1000
HISTFILESIZE=2000

# arch
arch=`uname -m`

# os
platform='unknown'
unamestr=`uname`
if [[ "$unamestr" == 'Darwin' ]]; then
  platform='osx'
elif [[ "$unamestr" == 'Linux' ]]; then
  platform='debian'
  # set xcape keymap
  source $HOME/.bin/start-xcape.sh
fi

# env
export PATH="$PATH:$HOME/.bin"
export PATH="/usr/local/sbin:$PATH"

# lang
if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
  export LC_ALL="en_US.UTF-8"
fi

# add line for prompt
function add_line {
  if [[ -z "${PS1_NEWLINE_LOGIN}" ]]; then
    PS1_NEWLINE_LOGIN=false
  else
    printf '\n'
  fi
}
PROMPT_COMMAND='add_line'

# git branch
function _git_branch () {
  # Get current Git branch
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

# comand prompt
if [ "$platform" = osx ]; then
  if [ "$arch" == 'arm64' ]; then
    export PS1="[${arch}]\u@\h:\[\e[36m\]\w\[\e[32m\]\$(_git_branch)\[\e[0m\]\$ "
  else
    export PS1="\u@\h:\[\e[36m\]\w\[\e[32m\]\$(_git_branch)\[\e[0m\]\$ "
  fi
elif [ "$platform" = debian ]; then
  # set variable identifying the chroot you work in (used in the prompt below)
  if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
  fi

  # set a fancy prompt (non-color, unless we know we "want" color)
  case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
  esac

  # uncomment for a colored prompt, if the terminal has the capability; turned
  # off by default to not distract the user: the focus in a terminal window
  # should be on the output of commands, not on the prompt
  #force_color_prompt=yes

  if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
      # We have color support; assume it's compliant with Ecma-48
      # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
      # a case would tend to support setf rather than setaf.)
      color_prompt=yes
    else
      color_prompt=
    fi
  fi

  if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
  else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
  fi
  unset color_prompt force_color_prompt

  # If this is an xterm set the title to user@host:dir
  case "$TERM" in
    xterm*|rxvt*)
      PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
      ;;
    *)
      ;;
  esac
fi

# aliases
alias ls='ls --color=auto'
alias ll='ls -al'
alias dockerrm='docker rm $(docker ps -aq)'
alias dockerrmi='docker rmi $(docker images -aq)'
alias dockerstop='docker stop $(docker ps -aq)'
alias dockerkill='docker kill $(docker ps -aq)'
alias emacsmin='emacs -nw --no-init-file --no-site-file'
alias emacs='emacs -nw'
alias screen='/usr/local/bin/screen'

# fzf
if which fzf > /dev/null 2>&1; then
  [ -f ~/.fzf.bash ] && source ~/.fzf.bash
else
  echo "installing fzf..."
  if [ "$platform" = osx ]; then
    brew install fzf
    $(brew --prefix)/opt/fzf/install
  fi
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


# for macos only setting
if [ "$platform" = osx ]; then
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
fi

# This loads nvm bash_completion
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
