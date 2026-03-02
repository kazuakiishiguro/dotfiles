# export Homebrew's sbin if apple m1
if [ `uname -m` == "arm64" ]; then
    export PATH="/opt/homebrew/sbin:$PATH"
fi

# Rust toolchain
if [ -e "$HOME/.cargo" ]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# sccache for Rust builds
if command -v sccache >/dev/null 2>&1; then
    export RUSTC_WRAPPER=$(which sccache)
fi

# nvm
if [ -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
fi

# rbenv
if [ -d "$HOME/.rbenv" ]; then
    export PATH=${HOME}/.rbenv/bin:${PATH} && \
    eval "$(rbenv init -)"
fi

# GPG Agent
export GPG_TTY=$(tty)

# fzf setup
if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"
fi
