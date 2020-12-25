#!/bin/sh

set -eu

arch=`uname -m`

is_command() {
    # Checks for existence of string passed in as only function argument.
    # Exit value of 0 when exists, 1 if not exists. Value is the result
    # of the `command` shell built-in call.
    local check_command="$1"
    command -v "${check_command}" > /dev/null 2>&1
}

if is_command brew; then
    echo 'Homebrew is_command. Skipping install.'
elif [ '${uname}' == 'arch64' ]; then
    cd /opt
    mkdir homebrew
    sudo chown $USER:admin homebrew
    curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C homebrew
else
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo 'Updating Homebrew...'
brew update

if is_command ansible; then
    echo 'Ansible exists. Skipping brew install ansible.'
else
    brew install ansible
fi

# echo 'Ansible playbook exec. Running command ansible-playbook to localhost.'
# ansible-playbook -i localhost, -c local ./scripts/macos.yml
