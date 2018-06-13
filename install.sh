#!/usr/bin/env bash

command_exists() {
  type "$1" > /dev/null 2>&1
}

[[ "$1" == "source" ]] || \

echo 'Dotfiles - Kazuaki Ishiguro'

if [[ "$1" == "-h" || "$1" == "--help" ]]; then cat <<HELP
Usage: $(basename "$0")
See the README for documentation.
https://github.com/kazuakiishiguro/dotfiles
HELP
exit; fi

echo "Initializing submodule(s)"
git submodule update --init --recursive

source install/link.sh
source install/git.sh

# OS INSTALLATIONS
case ${OSTYPE} in 
  darwin*)
  if [ "$(uname)" == "Darwin" ]; then
    echo -e "\\n\\nRunning on OSX"
    source install/brew.sh
    source install/osx.sh
  fi
esac

if ! command_exists zsh; then
  echo "zsh not found. Please install and then re-run installation scripts"
  exit 1
elif ! [[ $SHELL =~ .*zsh.* ]]; then
  echo "Configuring zsh as default shell"
  chsh -s "$(which zsh)"
fi

echo "Done. Reload your terminal."
