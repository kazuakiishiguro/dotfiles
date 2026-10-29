#!/usr/bin/env bash

# Compatibility entry point. The installer uses setup-system.sh directly.
# No full upgrade, AUR-helper bootstrap, source Emacs build, or directory change.
set -euo pipefail
setup_script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if command -v omarchy >/dev/null 2>&1; then
    bash "$setup_script_dir/setup-system.sh" --profile omarchy "$@"
else
    bash "$setup_script_dir/setup-system.sh" --profile linux "$@"
fi
