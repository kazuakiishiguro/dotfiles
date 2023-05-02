#!/bin/bash

set -eu

yay

source ./scripts/utils.sh

# install curl
if is_command curl; then
    echo "curl exists"
else
    yay -S curl
fi

# install emacs
if is_command emacs; then
    echo "emacs exists"
else
    yay -S emacs
fi
