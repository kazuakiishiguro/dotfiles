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
    "bash"
    "bin"
    "config"
    "emacs"
    "git"
    "local"
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

for module in ${modules[@]}; do
    # Collect conflicting paths from stow dry-run
    conflicts=$(stow -t ~ -n --adopt "$module" 2>&1 | grep "existing target" | sed 's/.*: //' || true)
    if [ -n "$conflicts" ]; then
        mkdir -p "$backup_dir"
        for target in $conflicts; do
            target_path="$HOME/$target"
            if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
                mkdir -p "$backup_dir/$(dirname "$target")"
                mv "$target_path" "$backup_dir/$target"
                echo "backed up $target_path -> $backup_dir/$target"
            fi
        done
    fi
    stow -t ~ -v --adopt "$module"
done

# --adopt overwrites package files with existing target contents;
# restore our versions from git
git checkout .

if [ -d "${backup_dir:-}" ]; then
    echo "pre-existing files backed up to $backup_dir"
fi
