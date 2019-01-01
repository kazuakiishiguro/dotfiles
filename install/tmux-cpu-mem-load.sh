#!/usr/bin/env bash

set -e

if type cmake > /dev/null 2>&1; then
  if [[ "$OSTYPE" == "darwin" ]]; then
    cmd="brew"
  else
    cmd="sudo apt"
  fi 
  $cmd install cmake
fi 

cd $HOME/.tmux-cpu-mem-load
cmake .
make
sudo make install