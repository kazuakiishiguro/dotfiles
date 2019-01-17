#!/usr/bin/env bash

set -e

if ! type cmake > /dev/null 2>&1; then
  unameOut="$(uname -s)"
  case "${unameOut}" in
    Linux*)     cmd=suso apt;;
    Darwin*)    cmd=brew;;
    *)          machine="UNKNOWN:${unameOut}"
  esac
  $cmd install cmake
fi
cd $HOME/.tmux-mem-cpu-load
cmake .
make
sudo make install