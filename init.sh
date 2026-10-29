#!/usr/bin/env bash
# A single, cwd-independent entry point; implementation lives in scripts/.
set -euo pipefail
dotfiles_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
if ! command -v python3 >/dev/null 2>&1; then
    printf 'Python 3 is required. Install it first, or use bootstrap.sh.\n' >&2
    exit 1
fi
exec python3 "$dotfiles_root/scripts/install.py" "$@"
