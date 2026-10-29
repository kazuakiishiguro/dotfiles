# Login commands need the shared environment too. Zsh loads .zshrc itself
# for interactive shells; sourcing it here would run its integrations twice.
if [ -f "$HOME/.shellrc" ]; then
  . "$HOME/.shellrc"
fi

# load .zprofile.local
if [ -e "$HOME/.zprofile.local" ]; then
  . "$HOME/.zprofile.local"
fi

# cargo
if [ -e "$HOME/.cargo" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

# nvm
if [ -e "$HOME/.nvm" ]; then
  export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  if [[ $- == *i* ]]; then
    [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  fi
fi

# rbenv
if [ -e "$HOME/.rbenv"  ]; then
  export PATH=${HOME}/.rbenv/bin:${PATH} && \
  eval "$(rbenv init -)"
fi
