#!/usr/bin/env bash

command_exists() {
  type "$1" > /dev/null 2>&1
}

# Set ENG for home folder
env LANGUAGE=C LC_MESSAGES=C xdg-user-dirs-gtk-update

# Upgrade
read -sp "Password: " password
source ./bin/apt

# Remove Basic apps
echo $password | sudo apt-get remove unity-webapps-common xul-ext-unity xul-ext-websites-integration

# Install basic package
echo $password | sudo -S apt install -y tree curl vim vim-gnome apt-transport-https ca-certificates software-properties-common curl

# Install if zsh is not installed
if ! command_exists zsh; then
  echo $password | sudo -S apt install zsh
fi

# Install pip3 
if ! command_exists pip; then
  echo "Installing pip"
  echo $password | sudo apt install python3-distutils
  wget https://bootstrap.pypa.io/get-pip.py
  echo $password | sudo -S python3 get-pip.py
  rm get-pip.py
fi

# Install pyenv
if ! command_exists pyenv; then
  git clone https://github.com/yyuu/pyenv.git ~/.pyenv
  export PYENV_ROOT=$HOME/.pyenv
  export PATH=$PYENV_ROOT/bin:$PATH
  eval "$(pyenv init -)"
  pyenv --version
fi

# Install virtualenv
if ! command_exists virtualenv; then
  echo $password | sudo apt install virtualenv virtualenvwrapper
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

if ! command_exists docker-compose; then
  echo $password | sudo curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
  echo $password | sudo chmod +x /usr/local/bin/docker-compose
fi

# nvim 
if ! command_exists nvim; then
  sudo apt-get install software-properties-common
  sudo add-apt-repository ppa:neovim-ppa/unstable
  sudo apt install neovim
  sudo pip3 install -U pip
  sudo pip3 install neovim
  which nvim
fi