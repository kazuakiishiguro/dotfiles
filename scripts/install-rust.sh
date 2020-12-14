#!/bin/bash

set -eu

OS=$1

# install rust analyzer

exists() { type -t "$1" > /dev/null 2>&1; }

if exists rust-analyzer; then
    echo "rust-analyzer exists"
else
    echo "Installing rsut-analyzer"
    curl -L \
	 https://github.com/rust-analyzer/rust-analyzer/releases/latest/download/rust-analyzer-$OS \
	 -o ~/.bin/rust-analyzer    
fi

