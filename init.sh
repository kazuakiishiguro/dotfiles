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

backup_dir="$HOME/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"
dotfiles_dir="$(cd "$(dirname "$0")" && pwd)"

# Back up files that would conflict with stow (skip stow-managed symlinks)
for module in ${modules[@]}; do
    find "$module" -mindepth 1 -not -type d | while read -r src; do
        rel="${src#"$module"/}"
        target="$HOME/$rel"
        if [ -L "$target" ] || [ -e "$target" ]; then
            if command -v greadlink >/dev/null 2>&1; then
                resolved="$(greadlink -f "$target" 2>/dev/null || true)"
            else
                resolved="$(readlink -f "$target" 2>/dev/null || true)"
            fi
            # Skip files already managed by stow (pointing into our dotfiles)
            if [[ "$resolved" == "$dotfiles_dir"* ]]; then
                continue
            fi
            mkdir -p "$backup_dir/$(dirname "$rel")"
            mv "$target" "$backup_dir/$rel"
            echo "backed up $target -> $backup_dir/$rel"
        fi
    done
done

for module in ${modules[@]}; do
    stow -t ~ -v --no-folding --adopt "$module"
done

# --adopt overwrites package files with existing target contents;
# restore our versions from git
git checkout .

if [ -d "${backup_dir:-}" ]; then
    echo "pre-existing files backed up to $backup_dir"
fi

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
