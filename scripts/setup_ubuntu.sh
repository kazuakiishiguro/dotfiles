#!/bin/bash

set -eu

sudo apt update

exists() { type -t "$1" > /dev/null 2>&1; }

# install linuxbrew-wrapper
if exists brew; then
  echo "brew exists"
else
  sudo apt install linuxbrew-wrapper build-essential libtool-bin
fi

# install cmake
if exists cmake; then
  echo "cmake exists"
else
  brew update
  brew install cmake
fi

# install git
if exists git; then
  echo "git exists"
else
  sudo apt install -y git
fi

# install xcape
if exists xcape; then
  echo "xcape exists"
else
  sudo apt install -y xcape
fi

# install fzf
if exists fzf; then
  echo "fzf exists"
else
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install
fi

# install emacs
if exists emacs; then
  echo "emacs exists"
else
  sudo add-apt-repository ppa:kelleyk/emacs
  sudo apt update
  sudo apt-get install -y emacs26
fi