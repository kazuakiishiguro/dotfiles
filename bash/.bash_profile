# silence macos bash warning
export BASH_SILENCE_DEPRECATION_WARNING=1

# always load .bashrc
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# lang
if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
  export LC_ALL="en_US.UTF-8"
fi

# export Homebrew's sbin if apple m1
if [ `uname -m` == "arm64" ]; then
    export PATH="/opt/homebrew/sbin:$PATH"
fi

# cargo
if [ -e "$HOME/.cargo" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

# nvm
if [ -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
fi

# rbenv
if [ -d "$HOME/.rbenv" ]; then
    export PATH=${HOME}/.rbenv/bin:${PATH} && \
    eval "$(rbenv init -)"
fi
