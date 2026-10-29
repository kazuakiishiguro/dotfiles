#!/usr/bin/env bash
# Package acquisition is explicit; regular Emacs startup stays network-free.
set -Eeuo pipefail

emacs_config_dir=""
emacs_check_only=false
emacs_reload=false
while (( $# )); do
  case "$1" in
    --config-dir)
      if (( $# < 2 )) || [[ -z "$2" ]]; then
        printf 'Missing directory after --config-dir\n' >&2
        exit 2
      fi
      emacs_config_dir="$2"
      shift 2 ;;
    --check-only) emacs_check_only=true; shift ;;
    --reload) emacs_reload=true; shift ;;
    --packages-only) shift ;; # Compatibility with the former local helper.
    --help|-h)
      cat <<'EOF'
Usage: scripts/setup-emacs.sh [--config-dir DIR] [--check-only] [--reload]
Install missing Emacs packages and validate the complete shared configuration.
System tools are installed by ./init.sh, before this script runs.
--check-only validates without downloading packages or setting up Omarchy.
--reload reloads a running daemon after successful validation (opt-in).
EOF
      exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [[ -z "$emacs_config_dir" ]]; then
  if [[ -d "${XDG_CONFIG_HOME:-$HOME/.config}/emacs" ]]; then
    emacs_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/emacs"
  else
    emacs_config_dir="$HOME/.emacs.d"
  fi
fi
if [[ ! -d "$emacs_config_dir" ]]; then
  printf 'Emacs configuration directory is missing: %s\nRun ./init.sh from the dotfiles repository first.\n' "$emacs_config_dir" >&2
  exit 1
fi
emacs_config_dir="$(cd "$emacs_config_dir" && pwd -P)"
for emacs_required_file in packages.el init.el check-config.el; do
  if [[ ! -r "$emacs_config_dir/$emacs_required_file" ]]; then
    printf 'Missing shared Emacs file: %s/%s\nRun ./init.sh from the dotfiles repository first.\n' "$emacs_config_dir" "$emacs_required_file" >&2
    exit 1
  fi
done

emacs_binary="${EMACS:-emacs}"
if ! command -v "$emacs_binary" >/dev/null 2>&1; then
  printf 'Emacs is not installed. Run ./init.sh to install system dependencies.\n' >&2
  exit 1
fi
emacs_major_version="$("$emacs_binary" --batch -Q --eval '(princ emacs-major-version)')"
case "$emacs_major_version" in
  ''|*[!0-9]*) printf 'Could not determine Emacs version: %s\n' "$emacs_major_version" >&2; exit 1 ;;
esac
if (( emacs_major_version < 29 )); then
  printf 'Emacs 29 or newer is required (found %s).\n' "$emacs_major_version" >&2
  exit 1
fi

emacs_setup_log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
mkdir -p "$emacs_setup_log_dir"
emacs_setup_log="$emacs_setup_log_dir/emacs-setup-$(date +%Y%m%d-%H%M%S)-$$.log"
exec > >(tee "$emacs_setup_log") 2>&1
printf 'Emacs setup log: %s\n' "$emacs_setup_log"
emacs_setup_step='preparing Omarchy integration'
trap 'printf "Emacs setup failed while %s (line %s). Installed packages are retained. See %s\n" "$emacs_setup_step" "$LINENO" "$emacs_setup_log" >&2' ERR

# Use the package-owned installer only when its managed files are absent.
# It hardcodes ~/.config/emacs; an ordinary ~/.emacs.d profile must not change
# the unrelated Omarchy configuration. Existing managed files stay untouched.
if [[ "$emacs_config_dir" == "$HOME/.config/emacs" ]] &&
   { command -v omarchy >/dev/null 2>&1 ||
     [[ -r /usr/share/omarchy-emacs/config/omarchy.el ]]; } &&
   { [[ ! -r "$emacs_config_dir/omarchy.el" ]] ||
     [[ ! -r "$emacs_config_dir/themes/omarchy-theme.el" ]]; }; then
  if "$emacs_check_only"; then
    printf 'Omarchy Emacs integration is incomplete; rerun ./init.sh without --check-only.\n' >&2
    exit 1
  fi
  for emacs_legacy_path in "$HOME/.emacs" "$HOME/.emacs.el" "$HOME/.emacs.d"; do
    if [[ -e "$emacs_legacy_path" || -L "$emacs_legacy_path" ]]; then
      printf 'Conflicting Emacs startup path: %s\nRun ./init.sh so it is backed up before migration.\n' "$emacs_legacy_path" >&2
      exit 1
    fi
  done
  if ! command -v omarchy-emacs-setup >/dev/null 2>&1; then
    printf 'omarchy-emacs-setup is missing; rerun ./init.sh to install omarchy-emacs.\n' >&2
    exit 1
  fi
  # Generate Emacs colors using Omarchy 4's headless theme path. Desktop hooks
  # can reload Emacs too, so keep them and background changes out of setup.
  OMARCHY_THEME_HEADLESS=1 OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy-emacs-setup </dev/null
  if [[ ! -r "$emacs_config_dir/omarchy.el" ||
        ! -r "$emacs_config_dir/themes/omarchy-theme.el" ]]; then
    printf 'omarchy-emacs-setup did not create its managed shim and theme; inspect its output above.\n' >&2
    exit 1
  fi
fi

# Bash 3.2 (macOS) treats empty arrays as unset under nounset.
emacs_early_args=(--eval 'nil')
if [[ -r "$emacs_config_dir/early-init.el" ]]; then
  emacs_early_args=(--load "$emacs_config_dir/early-init.el")
fi
if ! "$emacs_check_only"; then
  emacs_setup_step='installing Emacs packages'
  "$emacs_binary" --batch -Q --init-directory "$emacs_config_dir" \
    "${emacs_early_args[@]}" --load "$emacs_config_dir/packages.el" \
    --eval '(my/install-dotfiles-emacs-packages)'
fi

emacs_setup_step='validating the complete Emacs configuration'
"$emacs_binary" --batch -Q --init-directory "$emacs_config_dir" \
  "${emacs_early_args[@]}" \
  --eval '(setq use-package-expand-minimally t debug-on-error t)' \
  --load "$emacs_config_dir/init.el" \
  --load "$emacs_config_dir/check-config.el" \
  --eval '(require (quote codex-ide))'

if "$emacs_reload"; then
  emacs_setup_step='reloading the running Emacs daemon'
  emacs_client_binary="${EMACSCLIENT:-emacsclient}"
  if command -v "$emacs_client_binary" >/dev/null 2>&1 &&
     "$emacs_client_binary" --alternate-editor=false --eval '(emacs-pid)' >/dev/null 2>&1; then
    # Have Emacs quote the path as Lisp, including spaces, quotes and newlines.
    emacs_config_literal="$(DOTFILES_EMACS_CONFIG_DIR="$emacs_config_dir" \
      "$emacs_binary" --batch -Q --eval \
      '(prin1 (file-name-as-directory (expand-file-name (getenv "DOTFILES_EMACS_CONFIG_DIR"))))')"
    "$emacs_client_binary" --alternate-editor=false --eval \
      "(let ((expected $emacs_config_literal))
         (unless (file-equal-p expected user-emacs-directory)
           (error \"Running daemon uses another configuration; restart it manually\"))
         (with-timeout (90 (error \"Emacs reload timed out\"))
           (load-file (expand-file-name \"init.el\" expected))
           (load-file (expand-file-name \"check-config.el\" expected))
           my/dotfiles-configuration-loaded))"
  else
    printf 'No running Emacs daemon found; open Emacs to activate the configuration.\n'
  fi
fi
printf 'Emacs packages and configuration are ready.\n'
