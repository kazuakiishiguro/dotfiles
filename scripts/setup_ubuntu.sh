#!/bin/bash

set -eu

sudo apt update

source ./scripts/utils.sh

# install fzf
if is_command fzf; then
    echo "fzf exists"
else
    sudo apt install -y fzf
fi

# install emacs
if is_command emacs; then
    echo "emacs exists"
else
    sudo apt install -y emacs
fi
