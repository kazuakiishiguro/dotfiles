#!/bin/bash

set -eu

DOTFILES_DIR="$HOME/fun/dotfiles"
REPO="https://github.com/kazuakiishiguro/dotfiles.git"

if [ -d "$DOTFILES_DIR" ]; then
    echo "dotfiles already exist at $DOTFILES_DIR"
    exit 1
fi

if ! command -v git > /dev/null 2>&1; then
    echo "installing git..."
    if [[ $(uname) == 'Darwin' ]]; then
        xcode-select --install
    elif [[ $(uname -a) == *Ubuntu* ]] || [[ $(uname -a) == *pop-os* ]]; then
        sudo apt update && sudo apt install -y git
    elif [[ $(uname -a) == *asahi* ]]; then
        sudo dnf install -y git
    elif [[ $(uname -a) == *arch* ]]; then
        sudo pacman -S --noconfirm git
    fi
fi

mkdir -p "$(dirname "$DOTFILES_DIR")"
git clone "$REPO" "$DOTFILES_DIR"
cd "$DOTFILES_DIR"
./init.sh
