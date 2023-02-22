#!/bin/bash

set -eu

is_command() {
    # Checks for existence of string passed in as only function argument.
    # Exit value of 0 when exists, 1 if not exists. Value is the result
    # of the `command` shell built-in call.
    local check_command="$1"
    command -v "${check_command}" > /dev/null 2>&1
}

# check if rust is installed
if is_command cargo; then
    echo "rust installed"
else
    echo "Install rust"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi

# install rust analyzer
if is_command rust-analyzer; then
    echo "rust-analyzer exists"
else
    echo "Installing rsut-analyzer"
    git clone https://github.com/rust-analyzer/rust-analyzer.git
    cd rust-analyzer
    cargo xtask install --server
    cd -
    rm -rf rust-analyzer
fi
