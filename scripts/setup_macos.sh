#!/bin/sh

set -eu

arch=`uname -m`

source ./scripts/utils.sh

cd $(dirname $0)

if is_command brew; then
    echo 'Homebrew is_command. Skipping install.'
else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew update
brew upgrade
brew bundle --file ./scripts/Brewfile
