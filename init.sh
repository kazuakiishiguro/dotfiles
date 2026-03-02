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

# Replace a tree-folded stow symlink with a real directory, moving contents back.
# e.g. ~/.config -> dotfiles/config/.config becomes a real ~/.config/ with files moved back.
unfold_tree() {
    local module="$1"
    for top in "$module"/.*/ "$module"/*/; do
        [ -d "$top" ] || continue
        local base
        base="$(basename "$top")"
        [[ "$base" == "." || "$base" == ".." ]] && continue
        local rel="${top#"$module"/}"
        rel="${rel%/}"
        local target="$HOME/$rel"
        if [ -L "$target" ]; then
            local resolved
            resolved="$(readlink -f "$target")"
            if [[ "$resolved" == "$dotfiles_dir"* ]]; then
                echo "unfolding tree-fold: $target -> $resolved"
                rm "$target"
                mkdir -p "$target"
                # Move everything from the repo dir to the real home dir
                local repo_dir="$dotfiles_dir/$module/$rel"
                if [ -d "$repo_dir" ]; then
                    find "$repo_dir" -mindepth 1 -maxdepth 1 -exec mv -n {} "$target/" \;
                fi
                # Restore tracked files in the repo so stow can link them
                git -C "$dotfiles_dir" checkout -- "$module/$rel" 2>/dev/null || true
            fi
        fi
    done
}

# Back up real files/dirs and foreign symlinks that would conflict with stow.
# Anything that already resolves into our dotfiles dir is stow-managed — leave it.
backup_conflicts() {
    local module="$1"
    find "$module" -mindepth 1 -not -type d | while read -r src; do
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
    unfold_tree "$module"
    backup_conflicts "$module"
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
