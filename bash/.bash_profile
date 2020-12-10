# always load .bashrc
if [ -f ~/.bashrc ] ; then
    . ~/.bashrc
fi

# added by Nix installer
if [ -e /Users/kazuaki/.nix-profile/etc/profile.d/nix.sh ]; then
    . /Users/kazuaki/.nix-profile/etc/profile.d/nix.sh;
fi
