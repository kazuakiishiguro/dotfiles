#!/bin/sh

set -eu

sudo dnf update

source ./scripts/utils.sh

# install fzf
if is_command fzf; then
    echo "fzf exists"
else
    sudo dnf install -y fzf
fi

# install emacs
if is_command emacs; then
    echo "emacs exists"
else
    sudo dnf install emacs
fi
