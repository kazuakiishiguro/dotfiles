#!/bin/bash

set -eu

# os setting
if [[ `uname` == 'Darwin' ]]; then
    OS="macos"
elif [[ `uname -a` == *Ubuntu* ]] || [[ `uname -a` == *pop-os* ]]; then
    OS="ubuntu"
elif [[ `uname -a` == *asahi* ]] ; then
    OS="fedora"
elif [[ `uname -a` == *arch* ]] ; then
    OS="arch"
fi

source ./scripts/setup_${OS}.sh
source ./scripts/install-rust.sh

modules=(
    "bin"
    "config"
    "emacs"
    "git"
    "screen"
    "vim"
    "zsh"
)

if [ ${OS} == 'arch' ]; then
    modules+=(
	"xinitrc"
	"Xmodmap"
	"xprofile"
    )
fi

if ! command -v stow > /dev/null 2>&1; then
  echo "installing stow..."
  if [ ${OS} == 'macos' ]; then
      brew install stow
  elif [ ${OS} == 'ubuntu' ]; then
      sudo apt install -y stow
  elif [ ${OS} == 'fedora' ]; then
      sudo dnf install -y stow
  elif [ ${OS} == 'arch' ]; then
      yay -S stow
  fi
fi

for module in ${modules[@]}; do
    stow -t ~ -v "$module"
done
