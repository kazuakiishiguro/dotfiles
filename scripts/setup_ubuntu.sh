#!/bin/bash

set -eu

sudo apt update

exists() { type -t "$1" > /dev/null 2>&1; }

# install git
if exists git; then
  echo "git exists"
else
  sudo apt install -y git
fi

# install xcape
if exists xcape; then
  echo "xcape exists"
else
  sudo apt install -y xcape
fi

# install fzf
if exists fzf; then
  echo "fzf exists"
else
  sudo apt install -y fzf
fi

# install emacs
if exists emacs; then
  echo "emacs exists"
else
  sudo add-apt-repository ppa:kelleyk/emacs
  sudo apt update
  sudo apt-get install -y emacs26
fi

# install brave browser
# this will install apt-transport https and curl packages as well
if exists brave-browser; then
  echo "brave browser exists"
else
  sudo apt install -y apt-transport-https curl
  curl -s https://brave-browser-apt-release.s3.brave.com/brave-core.asc | sudo apt-key --keyring /etc/apt/trusted.gpg.d/brave-browser-release.gpg add -
  echo "deb [arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
  sudo apt update
  sudo apt install -y brave-browser
fi

# install keybase
if exists keybase; then
  echo "keybase exists"
else
  curl --remote-name https://prerelease.keybase.io/keybase_amd64.deb
  sudo apt install -y ./keybase_amd64.deb
  run_keybase
fi
