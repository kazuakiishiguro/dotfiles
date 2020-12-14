#!/bin/bash

set -eu

# os setting
if [[ `uname` == 'Darwin' ]]; then
    source ./scripts/setup_macos.sh
    source ./scripts/install-rust.sh mac
 elif [[ `uname -a` == *Ubuntu* ]]; then
    source ./scripts/setup_ubuntu.sh
    source ./scripts/install-rust.sh linux
 fi

modules='
    bash
    bin
    emacs
    git
    screen
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
