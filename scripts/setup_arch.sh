#!/bin/bash

set -eu

yay

is_command() {
    # Checks for existence of string passed in as only function argument.
    # Exit value of 0 when exists, 1 if not exists. Value is the result
    # of the `command` shell built-in call.
    local check_command="$1"
    command -v "${check_command}" > /dev/null 2>&1
}

# install curl
if is_command curl; then
    echo "curl exists"
else
    yay -S curl
fi

# install emacs
if is_command emacs; then
    echo "emacs exists"
else
    yay -S emacs
fi
