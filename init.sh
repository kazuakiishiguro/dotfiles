#!/usr/bin/env bash

exists() { type -t "$1" > /dev/null 2>&1; }

[[ "$1" == "source" ]] || \

echo 'Dotfiles - Kazuaki Ishiguro'

if [[ "$1" == "-h" || "$1" == "--help" ]]; then cat <<HELP
Usage: $(basename "$0")
See the README for documentation.
https://github.com/kazuakiishiguro/dotfiles
HELP
exit; fi

echo "Initializing submodule(s)"
git submodule update --init --recursive

source install/link.sh
source install/git.sh

# OS INSTALLATIONS
case ${OSTYPE} in 
  darwin*)
    echo -e "\\n\\nRunning on OSX"
    source install/brew.sh
    source install/osx.sh
    ;;
  linux-gnu*)
    if [ -e /etc/debian_version ] || [ -e /etc/debian_release ]; then
      if [ -e /etc/lsb-release ]; then
        DISTRIBUTION_NAME="ubuntu"
      else
        DISTRIBUTION_NAME="debian"
      fi
    elif [ -e /etc/fedora-release ]; then
      DISTRIBUTION_NAME="fedora"
    elif [ -e /etc/redhat-release ]; then
      if [ -e /etc/oracle-release ]; then
        DISTRIBUTION_NAME="oracle"
      else
        DISTRIBUTION_NAME="redhat"
      fi
    elif [ -e /etc/turbolinux-release ]; then
      DISTRIBUTION_NAME="turbol"
    elif [ -e /etc/SuSE-release ]; then
      DISTRIBUTION_NAME="suse"
    elif [ -e /etc/mandriva-release ]; then
      DISTRIBUTION_NAME="mandriva"
    elif [ -e /etc/vine-release ]; then
      DISTRIBUTION_NAME="vine"
    elif [ -e /etc/gentoo-release ]; then
      DISTRIBUTION_NAME="gentoo"
    else
      echo "unkown distribution"
      DISTRIBUTION_NAME="unkown"
    fi
    echo -e "\\n\\nRunning on ${DISTRIBUTION_NAME}"
    source install/${DISTRIBUTION_NAME}.sh
    ;;
  *) echo "unknown: $OSTYPE" ;;
esac

if ! exists zsh; then
  echo "zsh not found. Please install and then re-run installation scripts"
  exit 1
elif ! [[ $SHELL =~ .*zsh.* ]]; then
  echo "Configuring zsh as default shell"
  chsh -s "$(which zsh)"
fi

echo "Done. Reload your terminal."
