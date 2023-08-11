#!/bin/bash

set -eu

source ./scripts/utils.sh

if is_command yay; then
    echo "yay exists"
    yay
else
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/yay.git ~/fun/yay
    cd ~/fun/yay && makepkg -si
fi

yay

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
    yay texinfo tree-sitter gnutls
    git clone --branch emacs-29 https://git.savannah.gnu.org/git/emacs.git ~/fun/emacs
    cd ~/fun/emacs
    ./autogen.sh
    ./configure --without-x --without-ns --without-native-compilation --with-tree-sitter
    make
    sudo make install
fi
