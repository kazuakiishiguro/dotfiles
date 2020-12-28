# silence macos bash warning
export BASH_SILENCE_DEPRECATION_WARNING=1

# always load .bashrc
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# added by Nix installer
if [ -e /Users/kazuaki/.nix-profile/etc/profile.d/nix.sh ]; then
    . /Users/kazuaki/.nix-profile/etc/profile.d/nix.sh;
fi

# export Homebrew's sbin if apple m1
if [ `uname -m` == "arm64" ]; then
    export PATH="/opt/homebrew/sbin:$PATH"
fi
