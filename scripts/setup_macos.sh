#!/bin/sh

set -eu

arch=`uname -m`

exists() { type -t "$1" > /dev/null 2>&1; }

if exists brew; then
  echo 'Homebrew exists. Skipping install.'
else if [ '${uname}' == 'arch64' ]; then
    cd /opt
    mkdir homebrew
    sudo chown $USER:admin homebrew
    curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C homebrew
else
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo 'Updating Homebrew...'
brew update

if exists ansible; then
  echo 'Ansible exists. Skipping brew install ansible.'
else
  brew install ansible
fi

echo 'Ansible playbook exec. Running command ansible-playbook to localhost.'
ansible-playbook -i localhost, -c local ./scripts/macos.yml
