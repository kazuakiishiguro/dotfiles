# silence macos bash warning
export BASH_SILENCE_DEPRECATION_WARNING=1

# always load .bashrc
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# export Homebrew's sbin if apple m1
if [ `uname -m` == "arm64" ]; then
    export PATH="/opt/homebrew/sbin:$PATH"
fi
