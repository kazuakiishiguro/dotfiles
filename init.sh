#!/bin/bash

modules='
    bin
    bash
    emacs
    git
    tmux
    vim
'

for module in $modules; do
    stow -t ~ -v $module
done
