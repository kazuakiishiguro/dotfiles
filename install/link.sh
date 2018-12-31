#!/usr/bin/env bash

DOTFILES=$HOME/.dotfiles
export XDG_CONFIG_HOME="$HOME/.config"

# -- symlink setting ----------------------------------------------------------
# echo -e "\\nCreating symlinks"
# echo "=============================="
# linkables=$( find -H "$DOTFILES" -maxdepth 3 -name '*.symlink' )
# for file in $linkables ; do
#   target="$HOME/.$( basename "$file" '.symlink' )"
#   if [ -e "$target" ]; then
#     echo "~${target#$HOME} already exists... Skipping."
#   else
#     echo "Creating symlink for $file"
#     ln -s "$file" "$target"
#   fi
# done

# -- config setting -----------------------------------------------------------
echo -e "\\n\\ninstalling to ~/.config"
echo "=============================="
if [ ! -d "$HOME/.config" ]; then
  echo "Creating ~/.config"
  mkdir -p "$HOME/.config"
fi

config_files=$( find "$DOTFILES/config" -maxdepth 1 -name 'nvim')
for config in $config_files; do
  target="$HOME/.config/$( basename "$config" )"
  if [ -e "$target" ]; then
    echo "~${target#$HOME} already exists... Skipping."
  else
    echo "Creating symlink for $config"
    ln -s "$config" "$target"
  fi
done

#-- neovim setting -----------------------------------------------------------
echo -e "\\n\\nCreating neovim symlinks"
echo "=============================="
VIMFILES=( "$HOME/.vim:$XDG_CONFIG_HOME/nvim"
        "$HOME/.vimrc:$XDG_CONFIG_HOME/nvim/init.vim" )

for file in "${VIMFILES[@]}"; do
    KEY=${file%%:*}
    VALUE=${file#*:}
    if [ -e "${KEY}" ]; then
        echo "${KEY} already exists... skipping."
    else
        echo "Creating symlink for $KEY"
        ln -s "${VALUE}" "${KEY}"
    fi
done