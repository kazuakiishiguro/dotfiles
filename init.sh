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
dotfiles_dir="$(cd "$(dirname "$0")" && pwd)"

# Back up real files/dirs and foreign symlinks that would conflict with stow.
# Anything that already resolves into our dotfiles dir is stow-managed — leave it.
backup_conflicts() {
    local module="$1"
    find "$module" -mindepth 1 | while read -r src; do
        local rel="${src#"$module"/}"
        local target="$HOME/$rel"
        if [ -L "$target" ] || [ -e "$target" ]; then
            local resolved
            resolved="$(readlink -f "$target" 2>/dev/null || true)"
            if [[ "$resolved" == "$dotfiles_dir"* ]]; then
                continue
            fi
            mkdir -p "$backup_dir/$(dirname "$rel")"
            mv "$target" "$backup_dir/$rel"
            echo "backed up $target -> $backup_dir/$rel"
        fi
    done
}

for module in ${modules[@]}; do
    backup_conflicts "$module"
    stow -t ~ -v --adopt "$module"
done

# --adopt overwrites package files with existing target contents;
# restore our versions from git
git checkout .

if [ -d "${backup_dir:-}" ]; then
    echo "pre-existing files backed up to $backup_dir"
fi
