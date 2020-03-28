#!/bin/bash

set -eu

# mac only setting
if [[ `uname` == 'Darwin' ]]; then
    source ./scripts/setup_macos.sh
fi

modules='
    bash
    bin
    emacs
    git
    tmux
    vim
'

if ! which stow > /dev/null 2>&1; then
  echo "installing stow..."
  if [[ `uname` == 'Darwin' ]]; then
    brew install stow
  else
    if [[ `uname -a` == *Ubuntu* ]]; then
      sudo apt install -y stow
    fi
  fi
fi

for module in $modules; do
    stow -t ~ -v $module
done
