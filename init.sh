#!/bin/bash

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
