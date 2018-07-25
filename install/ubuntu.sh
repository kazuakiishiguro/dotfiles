#!/usr/bin/env bash

command_exists() {
  type "$1" > /dev/null 2>&1
}

# Set ENG for home folder
env LANGUAGE=C LC_MESSAGES=C xdg-user-dirs-gtk-update

# Upgrade
read -sp "Password: " password
echo $password | sudo -S apt -y upgrade && apt update && apt autoremove && apt clean

# Install if zsh is not installed
if ! command_exists zsh; then
  echo $password | sudo -S apt install zsh
fi

# Install if tmux is not installed
if ! command_exists tmux; then
  echo $password | sudo -S apt install tmux
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

# install basic package
echo $password | sudo -S apt install -y tree curl vim vim-gnome code apt-transport-https ca-certificates software-properties-common

if ! command_exists docker; then
  # gpd pub key install
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

  # check public key
  sudo apt-key fingerprint 0EBFCD88

  # add repo
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

  # update 
  sudo apt-get update

  # install docker
  sudo apt-get install -y docker-ce
fi