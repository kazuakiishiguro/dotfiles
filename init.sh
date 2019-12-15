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

for module in $modules; do
    stow -t ~ -v $module
done
