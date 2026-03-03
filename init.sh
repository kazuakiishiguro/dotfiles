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
    "shell"
    "bash"
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
    stow -t ~ -v --no-folding --adopt "$module"
done

# --adopt overwrites package files with existing target contents;
# restore our versions from git
git checkout .

# Post-stow omarchy setup
OMARCHY_PATH="$HOME/.local/share/omarchy"
if [ -d "$OMARCHY_PATH" ]; then
    # Symlink elephant menu plugins (theme/background pickers for walker)
    mkdir -p "$HOME/.config/elephant/menus"
    ln -snf "$OMARCHY_PATH/default/elephant/omarchy_themes.lua" \
        "$HOME/.config/elephant/menus/omarchy_themes.lua"
    ln -snf "$OMARCHY_PATH/default/elephant/omarchy_background_selector.lua" \
        "$HOME/.config/elephant/menus/omarchy_background_selector.lua"

    # Set Brave as default browser
    if command -v brave &>/dev/null; then
        xdg-settings set default-web-browser brave-browser.desktop
    fi
fi
