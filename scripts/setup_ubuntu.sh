#!/bin/bash

set -eu

sudo apt update

is_command() {
    # Checks for existence of string passed in as only function argument.
    # Exit value of 0 when exists, 1 if not exists. Value is the result
    # of the `command` shell built-in call.
    local check_command="$1"
    command -v "${check_command}" > /dev/null 2>&1
}

# install fzf
if is_command fzf; then
  echo "fzf exists"
else
  sudo apt install -y fzf
fi

# install emacs
if is_command emacs; then
  echo "emacs exists"
else
  sudo apt remove --autoremove emacs emacs-common
  sudo add-apt-repository ppa:kelleyk/emacs
  sudo apt update
  sudo apt-get install -y emacs28
fi

if is_command Xorg; then # check if desktop or server
    # install keybase
    if is_command keybase; then
	echo "keybase exists"
    else
	curl --remote-name https://prerelease.keybase.io/keybase_amd64.deb
	sudo apt install -y ./keybase_amd64.deb
	run_keybase
    fi
fi
