#!/bin/bash

set -eu

OS=$1

# install rust analyzer

is_command() {
    # Checks for existence of string passed in as only function argument.
    # Exit value of 0 when exists, 1 if not exists. Value is the result
    # of the `command` shell built-in call.
    local check_command="$1"
    command -v "${check_command}" > /dev/null 2>&1
}

if is_command rust-analyzer; then
    echo "rust-analyzer exists"
else
    echo "Installing rsut-analyzer"
    curl -L \
	 https://github.com/rust-analyzer/rust-analyzer/releases/latest/download/rust-analyzer-$OS \
	 -o ~/.bin/rust-analyzer    
fi

