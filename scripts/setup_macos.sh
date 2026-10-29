#!/usr/bin/env bash
# Compatibility entry point; do not run the former full Homebrew upgrade.
set -euo pipefail
script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
exec bash "$script_directory/setup-macos.sh" "$@"
