# --- Function Definitions ---
function _is_command() {
    local check_command="$1"
    command -v "${check_command}" > /dev/null 2>&1
}

function _git_branch () {
    # Get current Git branch
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

# --- General Configuration ---
HISTSIZE=1000
HISTFILESIZE=2000

# Architecture detection
arch=`uname -m`

# Operating System detection
_uname_s=$(uname -s)
_uname_a=$(uname -a)

platform='unknown'

case "$_uname_s" in
    Darwin)
        platform='osx'
        ;;
    Linux)
        if [[ "$_uname_a" == *Ubuntu* ]]; then
            platform='debian'
            if _is_command Xorg && [ -n "$DISPLAY" ]; then
                source $HOME/.bin/start-xcape.sh
            fi
	elif [[ "$_uname_a" == *arch* ]]; then
	    platform='arch'
        else
            platform='fedora'
        fi
        ;;
    *)
        # platform remains 'unknown'
        ;;
esac

# Environment Paths
export PATH="$PATH:$HOME/.bin"
export PATH="/usr/local/sbin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# --- Platform-Specific and Common Settings ---
# macOS Specific Configurations

function _configure_macos_settings() {
    # Command Prompt for macOS
    if [ "$arch" == 'arm64' ]; then
        export PS1="[${arch}]\u@\h:\[\e[36m\]\w\[\e[32m\]\$(_git_branch)\[\e[0m\]\$ "
        # Export Homebrew path for arm64
        export PATH=/opt/homebrew/bin:$PATH
    else
        export PS1="\u@\h:\[\e[36m\]\w\[\e[32m\]\$(_git_branch)\[\e[0m\]\$ "
    fi

    # dircolors for macOS (using GNU coreutils via Homebrew)
    export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"
    if [ -f "$HOME/.dircolors" ]; then
        if _is_command dircolors; then
            eval $(dircolors $HOME/.dircolors/dircolors.256dark)
        elif _is_command gdircolors; then
            eval $(gdircolors $HOME/.dircolors/dircolors.256dark)
        fi
    fi
}

# Apply platform-specific settings based on detected platform
if [ "$platform" = osx ]; then
    _configure_macos_settings
else
    # Default prompt for non-macOS bash
    source ~/.local/share/dotfiles/bash/prompt
fi

# Aliases
source ~/.local/share/dotfiles/bash/aliases
