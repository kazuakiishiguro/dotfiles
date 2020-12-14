# always load .bashrc
if [ -f ~/.bashrc ] ; then
    . ~/.bashrc
fi

# silence macos bash warning
export BASH_SILENCE_DEPRECATION_WARNING=1

# added by Nix installer
if [ -e /Users/kazuaki/.nix-profile/etc/profile.d/nix.sh ]; then
    . /Users/kazuaki/.nix-profile/etc/profile.d/nix.sh;
fi
