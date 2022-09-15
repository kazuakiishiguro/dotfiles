#!/bin/bash

set -eu

# os setting
if [[ `uname` == 'Darwin' ]]; then
    OS="macos"
elif [[ `uname -a` == *Ubuntu* ]] || [[ `uname -a` == *pop-os* ]]; then
    OS="ubuntu"
elif [[ `uname -a` == *arch* ]]; then
    OS="arch"
fi

source ./scripts/setup_${OS}.sh
source ./scripts/install-rust.sh

modules=(
    "bash"
    "bin"
    "config"
    "emacs"
    "git"
    "screen"
    "vim"
)

if ! command -v stow > /dev/null 2>&1; then
  echo "installing stow..."
  if [ ${OS} == 'macos' ]; then
    brew install stow
  elif [ ${OS} == 'ubuntu' ]; then
      sudo apt install -y stow
  elif [ ${OS} == 'arch' ]; then
      yay -S stow
      modules+=("xinitrc")
  fi
fi

for module in ${modules[@]}; do
    stow -t ~ -v "$module"
done
