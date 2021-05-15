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

# install git
if is_command git; then
  echo "git exists"
else
  sudo apt install -y git
fi

# install xcape
if is_command xcape; then
  echo "xcape exists"
else
  sudo apt install -y xcape
fi

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
  sudo add-apt-repository ppa:kelleyk/emacs
  sudo apt update
  sudo apt-get install -y emacs27
fi

check_if_desktop() {
    IS_DESKTOP="false"

    displayManager=(
	'xserver-common'
	'zwayland'
    )
    for i in "${displayManager[@]}"; do
	dpkg-query --show --showformat='${Status}\n' $i 2> /dev/null | grep "install ok installed" &> /dev/null
	if [[ $? -eq 0 ]]; then
	    IS_DESKTOP="true"
	fi
    done
}

if $IS_DESKTOP; then
    # install brave browser
    # this will install apt-transport https and curl packages as well
    if is_command brave-browser; then
	echo "brave browser exists"
    else
	sudo apt install -y apt-transport-https curl
	curl -s https://brave-browser-apt-release.s3.brave.com/brave-core.asc | sudo apt-key --keyring /etc/apt/trusted.gpg.d/brave-browser-release.gpg add -
	echo "deb [arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
	sudo apt update
	sudo apt install -y brave-browser
    fi

    # install keybase
    if is_command keybase; then
	echo "keybase exists"
    else
	curl --remote-name https://prerelease.keybase.io/keybase_amd64.deb
	sudo apt install -y ./keybase_amd64.deb
	run_keybase
    fi
fi
