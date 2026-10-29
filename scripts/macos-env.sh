# Shared process-only paths for installers launched outside a login shell.
# Source from Bash; do not load user shell files or execute package managers.
dotfiles_macos_append_path() {
    [[ -d "$1" ]] || return 0
    case ":$PATH:" in *":$1:"*) ;; *) PATH="$PATH:$1" ;; esac
}

dotfiles_macos_environment() {
    [[ "$(uname -s)" == Darwin ]] || return 0
    local brew_command brew_prefix
    brew_command=$(command -v brew 2>/dev/null) || brew_command=
    if [[ -z "$brew_command" ]]; then
        for brew_prefix in /opt/homebrew /usr/local; do
            if [[ -x "$brew_prefix/bin/brew" ]]; then
                brew_command="$brew_prefix/bin/brew"
                break
            fi
        done
    fi
    # Append so an explicitly selected interpreter/editor/toolchain stays first.
    case "$brew_command" in
        */bin/brew)
            brew_prefix=${brew_command%/bin/brew}
            dotfiles_macos_append_path "$brew_prefix/bin"
            dotfiles_macos_append_path "$brew_prefix/sbin" ;;
    esac
    if ! command -v cargo >/dev/null 2>&1 && [[ -x "$HOME/.cargo/bin/cargo" ]]; then
        dotfiles_macos_append_path "$HOME/.cargo/bin"
    fi
    dotfiles_macos_append_path /Library/TeX/texbin
    dotfiles_macos_append_path "$HOME/.bin"
    export PATH
}

dotfiles_macos_environment
unset -f dotfiles_macos_environment dotfiles_macos_append_path
