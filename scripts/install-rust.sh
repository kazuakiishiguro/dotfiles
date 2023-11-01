#!/bin/bash

set -eu

source ./scripts/utils.sh

# check if rust is installed
if is_command cargo; then
    echo "rust installed"
else
    echo "Install rust"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    source "$HOME/.cargo/env"
fi

# install rust analyzer
if is_command rust-analyzer; then
    echo "rust-analyzer exists"
else
    echo "Installing rsut-analyzer"
    rustup component add rust-analyzer
fi
