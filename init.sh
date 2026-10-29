#!/usr/bin/env bash
# A single, cwd-independent entry point; implementation lives in scripts/.
set -euo pipefail
dotfiles_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$dotfiles_root/scripts/macos-env.sh"
# Apple launcher stubs can open an installation dialog. Check before Python
# starts; Git is also used while planning, including for --dry-run.
if [[ "$(uname -s)" == Darwin ]]; then
    for executable in python3 git; do
        selected_tool=$(command -v "$executable" || true)
        case "$selected_tool" in
            /usr/bin/python3|/usr/bin/git)
                if ! developer_directory=$(xcode-select -p 2>/dev/null) || [[ ! -d "$developer_directory" ]]; then
                    printf 'Install the Xcode command line tools with xcode-select --install, then rerun.\n' >&2
                    exit 1
                fi ;;
        esac
    done
fi
if ! command -v python3 >/dev/null 2>&1; then
    printf 'Python 3 is required. Install it first, or use bootstrap.sh.\n' >&2
    exit 1
fi
exec python3 "$dotfiles_root/scripts/install.py" "$@"
