#!/usr/bin/env bash
# Compatibility for the original preview-first dotfiles-apply command.
# All installation logic is in init.sh; this wrapper only selects its flags.
set -euo pipefail
dotfiles_root="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().parent.parent)' "${BASH_SOURCE[0]}")"
apply=false
forward=(--config-only)
for argument in "$@"; do
    case "$argument" in
        --apply) apply=true ;;
        *) forward+=("$argument") ;;
    esac
done
if [[ "$apply" == false ]]; then
    forward+=(--dry-run)
fi
exec bash "$dotfiles_root/init.sh" "${forward[@]}"
