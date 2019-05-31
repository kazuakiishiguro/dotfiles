#!/bin/bash

set -eu

echo "installing ricty font for emacs"

if [[ $"fc-list Ricty" ]]; then
    echo "already installed"
else
    brew tap sanemat/font
    brew install ricty
    cp -f /usr/local/opt/ricty/share/fonts/Ricty*.ttf ~/Library/Fonts/
    fc-cache -vf
fi

rcup -d . -x README.md
unlink ~/.install.sh