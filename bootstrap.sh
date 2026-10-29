#!/usr/bin/env bash

set -euo pipefail

repository_url="https://github.com/kazuakiishiguro/dotfiles.git"
dotfiles_dir="$HOME/fun/dotfiles"
dry_run=false
init_args=()

usage() {
    cat <<'EOF'
Usage: bash bootstrap.sh [--dir DIRECTORY] [init.sh options]

Clone into ~/fun/dotfiles, or reuse an existing checkout of this repository.
Existing files and Git changes are retained; bootstrap never pulls or resets.
All options other than --dir are forwarded to init.sh.

Example: bash bootstrap.sh --dir "$HOME/fun/dotfiles" --profile omarchy
Preview: bash bootstrap.sh --dry-run
EOF
}

while (($#)); do
    case "$1" in
        --dir)
            if (($# < 2)) || [[ -z "$2" || "$2" == --* ]]; then
                echo "bootstrap: --dir requires a directory" >&2
                exit 2
            fi
            dotfiles_dir="$2"; shift 2 ;;
        --dir=*)
            dotfiles_dir="${1#*=}"
            [[ -n "$dotfiles_dir" ]] || { echo "bootstrap: empty --dir" >&2; exit 2; }
            shift ;;
        -h|--help) usage; exit 0 ;;
        --dry-run) dry_run=true; init_args+=("$1"); shift ;;
        --) shift; init_args+=("$@"); break ;;
        *) init_args+=("$1"); shift ;;
    esac
done

# A forwarded --dry-run must also prevent bootstrap's own clone/install steps.
# Bash 3.2 treats empty arrays as unset under nounset. The conditional expansion
# also preserves empty arguments when the array actually contains them.
for argument in ${init_args[@]+"${init_args[@]}"}; do
    [[ "$argument" != --dry-run ]] || dry_run=true
done

print_command() {
    printf '  '
    printf '%q ' "$@"
    printf '\n'
}

platform="$(uname -s)"
developer_tools_ready=false
if [[ "$platform" == Darwin ]]; then
    # SSH and fresh shells may not include Homebrew yet. Discover an existing
    # installation without changing the user's shell files or replacing PATH.
    if ! command -v brew >/dev/null 2>&1; then
        for brew_prefix in /opt/homebrew /usr/local; do
            if [[ -x "$brew_prefix/bin/brew" ]]; then
                export PATH="$brew_prefix/bin:$brew_prefix/sbin:$PATH"
                break
            fi
        done
    fi
    # Apple provides Git/Python launcher stubs even when the developer tools
    # are absent. Do not execute those stubs (including during --dry-run), as
    # they can open the command line tools installation dialog.
    if developer_directory=$(xcode-select -p 2>/dev/null) && [[ -d "$developer_directory" ]]; then
        developer_tools_ready=true
    fi
fi

tool_works() {
    local executable
    executable=$(command -v "$1") || return 1
    if [[ "$platform" == Darwin && "$developer_tools_ready" == false ]]; then
        case "$executable" in
            /usr/bin/git|/usr/bin/python3) return 1 ;;
        esac
    fi
    "$executable" --version >/dev/null 2>&1
}

# init.sh uses Python's standard library. Bootstrap only the missing tools;
# application dependencies are handled by scripts/setup-system.sh afterwards.
missing_tools=()
for executable in git python3; do
    tool_works "$executable" || missing_tools+=("$executable")
done
if ((${#missing_tools[@]})); then
    packages=()
    if command -v omarchy >/dev/null 2>&1 && command -v pacman >/dev/null 2>&1; then
        for executable in "${missing_tools[@]}"; do
            case "$executable" in python3) packages+=(python) ;; *) packages+=("$executable") ;; esac
        done
        install_command=(omarchy pkg add "${packages[@]}")
    elif [[ "$platform" == Darwin ]]; then
        if [[ "$developer_tools_ready" == false ]]; then
            echo "bootstrap: install the Xcode command line tools with xcode-select --install, then rerun; no installer dialog was opened." >&2
            exit 1
        fi
        if ! command -v brew >/dev/null 2>&1; then
            echo "bootstrap: install the Xcode command line tools and Homebrew first; git and python3 are required." >&2
            exit 1
        fi
        for executable in "${missing_tools[@]}"; do
            case "$executable" in python3) packages+=(python) ;; *) packages+=("$executable") ;; esac
        done
        install_command=(brew install "${packages[@]}")
    elif command -v apt-get >/dev/null 2>&1; then
        install_command=(sudo apt-get install -y "${missing_tools[@]}")
    elif command -v dnf >/dev/null 2>&1; then
        install_command=(sudo dnf install -y "${missing_tools[@]}")
    elif command -v pacman >/dev/null 2>&1; then
        for executable in "${missing_tools[@]}"; do
            case "$executable" in python3) packages+=(python) ;; *) packages+=("$executable") ;; esac
        done
        install_command=(sudo pacman -S --needed --noconfirm "${packages[@]}")
    else
        echo "bootstrap: install git and python3 before continuing." >&2
        exit 1
    fi
    echo "Bootstrap prerequisites:"
    print_command "${install_command[@]}"
    if [[ "$dry_run" == false ]]; then
        "${install_command[@]}"
        for executable in git python3; do
            tool_works "$executable" || { echo "bootstrap: $executable is still unavailable or not working" >&2; exit 1; }
        done
    fi
fi

if [[ -e "$dotfiles_dir" || -L "$dotfiles_dir" ]]; then
    if ! tool_works git; then
        echo "bootstrap: git is required to verify this existing directory." >&2
        exit 1
    fi
    if ! checkout_root=$(git -C "$dotfiles_dir" rev-parse --show-toplevel 2>/dev/null); then
        echo "bootstrap: $dotfiles_dir exists but is not a Git checkout; it was left untouched." >&2
        exit 1
    fi
    canonical_dir=$(cd "$dotfiles_dir" && pwd -P)
    canonical_root=$(cd "$checkout_root" && pwd -P)
    if [[ "$canonical_dir" != "$canonical_root" ]]; then
        echo "bootstrap: --dir must point to the repository root." >&2
        exit 1
    fi
    # Read the configured URL without applying local insteadOf rewrites.
    origin=$(git -C "$dotfiles_dir" config --get remote.origin.url || true)
    case "$origin" in
        https://github.com/kazuakiishiguro/dotfiles|https://github.com/kazuakiishiguro/dotfiles.git|git@github.com:kazuakiishiguro/dotfiles|git@github.com:kazuakiishiguro/dotfiles.git|ssh://git@github.com/kazuakiishiguro/dotfiles|ssh://git@github.com/kazuakiishiguro/dotfiles.git) ;;
        *) echo "bootstrap: existing checkout has a different origin; it was left untouched." >&2; exit 1 ;;
    esac
    echo "Reusing $dotfiles_dir (without pulling or resetting)."
else
    echo "Clone repository:"
    print_command git clone "$repository_url" "$dotfiles_dir"
    if [[ "$dry_run" == true ]]; then
        print_command bash "$dotfiles_dir/init.sh" ${init_args[@]+"${init_args[@]}"}
        exit 0
    fi
    mkdir -p "$(dirname "$dotfiles_dir")"
    git clone "$repository_url" "$dotfiles_dir"
fi

[[ -f "$dotfiles_dir/init.sh" ]] || { echo "bootstrap: checkout has no init.sh" >&2; exit 1; }
exec bash "$dotfiles_dir/init.sh" ${init_args[@]+"${init_args[@]}"}
