#!/usr/bin/env bash

command_exists() {
  type "$1" > /dev/null 2>&1
}


printf "password: "
read password
echo "$password" | sudo -S apt-get -y upgrade && apt-get update

# Install if zsh is not installed
if ! command_exists zsh; then
  echo "$password" | sudo -S apt-get install zsh
fi

# Install if tmux is not installed
if ! command_exists tmux; then
  echo "$password" | sudo -S apt-get install tmux
fi

# Change the default shell to zsh
zsh_path="$( which zsh )"
if ! grep "$zsh_path" /etc/shells; then
  echo "adding $zsh_path to /etc/shells"
  echo "$zsh_path" | sudo tee -a /etc/shells
fi

if [[ "$SHELL" != "$zsh_path" ]]; then
  chsh -s "$zsh_path"
  echo "default shell changed to $zsh_path"
fi