# for brew
eval "$(/opt/homebrew/bin/brew shellenv)"

# always load .zshrc
if [ -e "$HOME/.zshrc" ]; then
  . "$HOME/.zshrc"
fi

# load .zprofile.local
if [ -e "$HOME/.zprofile.local" ]; then
  . "$HOME/.zprofile.local"
fi

# lang
if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
  export LC_ALL="en_US.UTF-8"
fi

# cargo
if [ -e "$HOME/.cargo" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

# nvm
if [ -e "$HOME/.nvm" ]; then
  export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
fi

# rbenv
if [ -e "$HOME/.rbenv"  ]; then
  export PATH=${HOME}/.rbenv/bin:${PATH} && \
  eval "$(rbenv init -)"
fi
