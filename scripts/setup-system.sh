#!/usr/bin/env bash

# Install missing prerequisites only. No distribution upgrade, source build,
# dotfile writes, or Rust toolchain switch.
set -euo pipefail

profile=""
skip_emacs=false
dry_run=false
while (($#)); do
    case "$1" in
        --profile)
            (($# >= 2)) || { echo "setup-system: --profile requires a value" >&2; exit 2; }
            profile="$2"; shift 2 ;;
        --skip-emacs) skip_emacs=true; shift ;;
        --dry-run) dry_run=true; shift ;;
        -h|--help)
            echo "Usage: setup-system.sh --profile omarchy|linux|macos [--skip-emacs] [--dry-run]"
            exit 0 ;;
        *) echo "setup-system: unknown argument: $1" >&2; exit 2 ;;
    esac
done
case "$profile" in
    omarchy|linux|macos) ;;
    *) echo "setup-system: specify --profile omarchy, linux, or macos" >&2; exit 2 ;;
esac

if [[ "$profile" == macos ]]; then
    macos_args=()
    [[ "$skip_emacs" == false ]] || macos_args+=(--skip-emacs)
    [[ "$dry_run" == false ]] || macos_args+=(--dry-run)
    script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
    exec bash "$script_directory/setup-macos.sh" ${macos_args[@]+"${macos_args[@]}"}
fi

run() {
    printf '  '
    printf '%q ' "$@"
    printf '\n'
    [[ "$dry_run" == true ]] || "$@"
}

tool_works() {
    command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1
}

verify_tools() {
    local failed=false executable python_path
    local tools=(git python3 curl fzf)
    if [[ "$skip_emacs" == false ]]; then
        tools+=(emacs cargo rustc rustfmt rust-analyzer lldb flake8 black pdflatex pandoc)
    fi
    for executable in "${tools[@]}"; do
        if ! tool_works "$executable"; then
            printf 'setup-system: prerequisite is unavailable or not working: %s\n' "$executable" >&2
            failed=true
        fi
    done
    if [[ "$skip_emacs" == false ]] && ! python3 -c 'import jedi, rope, flake8, black' >/dev/null 2>&1; then
        python_path=$(command -v python3 || true)
        printf 'setup-system: Python backend dependencies cannot be imported by %s\n' "${python_path:-python3}" >&2
        echo 'Omarchy packages target /usr/bin/python3. Deactivate a conflicting virtualenv or mise Python override and rerun, or install jedi, rope, flake8, and black into the selected interpreter.' >&2
        failed=true
    fi
    if [[ "$skip_emacs" == false ]] && ! cargo clippy --version >/dev/null 2>&1; then
        echo 'setup-system: cargo clippy is required by the configured Rust checker.' >&2
        failed=true
    fi
    [[ "$failed" == false ]]
}

if [[ "$profile" != omarchy ]]; then
    # Generic Linux remains check-only; distribution package policies vary.
    missing_tools=()
    tools=(git python3 curl fzf)
    if [[ "$skip_emacs" == false ]]; then
        tools+=(emacs cargo rustc rustfmt rust-analyzer lldb flake8 black pandoc pdflatex)
    fi
    for executable in "${tools[@]}"; do
        command -v "$executable" >/dev/null 2>&1 || missing_tools+=("$executable")
    done
    if ((${#missing_tools[@]})); then
        printf 'setup-system: missing prerequisites on %s: %s\n' "$profile" "${missing_tools[*]}" >&2
        echo "Install them with this host's package manager, or use init.sh --config-only to apply settings without provisioning." >&2
        [[ "$dry_run" == true ]] && exit 0
        exit 1
    fi
    if [[ "$dry_run" == false ]] && ! verify_tools; then
        exit 1
    fi
    echo "System prerequisites are already available ($profile)."
    exit 0
fi

command -v omarchy >/dev/null 2>&1 || { echo "setup-system: Omarchy CLI is unavailable" >&2; exit 1; }
command -v pacman >/dev/null 2>&1 || { echo "setup-system: pacman is unavailable" >&2; exit 1; }

# Omarchy integration requires emacs-wayland, which conflicts with Arch's
# plain emacs package. Resolve that replacement interactively before making
# any package changes; the noninteractive Omarchy wrapper cannot approve it.
if [[ "$skip_emacs" == false ]] &&
   ! pacman -Q omarchy-emacs >/dev/null 2>&1 &&
   pacman -Q emacs >/dev/null 2>&1; then
    echo 'setup-system: omarchy-emacs requires replacing the installed emacs package with emacs-wayland.' >&2
    echo 'Run sudo pacman -S emacs-wayland in a terminal, review the replacement, then rerun ./init.sh. Use --skip-emacs to retain the current editor.' >&2
    if [[ "$dry_run" == true ]]; then
        echo 'Dry run: resolve this Emacs package conflict before provisioning; no packages were changed.'
        exit 0
    fi
    exit 1
fi

packages=(git python curl fzf fcitx5-mozc)
rustup_components=()
if [[ "$skip_emacs" == false ]]; then
    # Retain any existing Emacs executable and Rust toolchain. omarchy-emacs
    # itself depends on emacs-wayland when the integration must be installed.
    command -v emacs >/dev/null 2>&1 || packages+=(emacs-wayland)
    if command -v rustup >/dev/null 2>&1 || pacman -Q rustup >/dev/null 2>&1; then
        # Shims can exist without an active toolchain or installed component.
        # Never install Arch's conflicting rust package over a rustup setup.
        if ! command -v rustup >/dev/null 2>&1 || ! rustup show active-toolchain >/dev/null 2>&1; then
            echo 'setup-system: rustup has no working active toolchain. Run rustup default stable, then rerun this installer.' >&2
            [[ "$dry_run" == true ]] && exit 0
            exit 1
        fi
        if ! tool_works cargo || ! tool_works rustc; then
            echo 'setup-system: the selected rustup toolchain cannot run cargo/rustc. Repair that toolchain with rustup and rerun; no toolchain was switched.' >&2
            [[ "$dry_run" == true ]] && exit 0
            exit 1
        fi
        tool_works rustfmt || rustup_components+=(rustfmt)
        tool_works rust-analyzer || rustup_components+=(rust-analyzer)
        cargo clippy --version >/dev/null 2>&1 || rustup_components+=(clippy)
    else
        if ! tool_works cargo || ! tool_works rustc || ! tool_works rustfmt; then
            packages+=(rust)
        fi
        tool_works rust-analyzer || packages+=(rust-analyzer)
    fi
    command -v lldb >/dev/null 2>&1 || packages+=(lldb)
    packages+=(python-jedi python-rope python-flake8 python-black)
    command -v pdflatex >/dev/null 2>&1 || packages+=(texlive-latexrecommended)
    command -v pandoc >/dev/null 2>&1 || packages+=(pandoc-cli)
fi

missing_packages=()
for package in "${packages[@]}"; do
    pacman -Q "$package" >/dev/null 2>&1 || missing_packages+=("$package")
done
if ((${#missing_packages[@]})); then
    echo "Missing system packages:"
    run omarchy pkg add "${missing_packages[@]}"
else
    echo "System packages are already installed."
fi

if ((${#rustup_components[@]})); then
    echo 'Missing components in the selected rustup toolchain:'
    run rustup component add "${rustup_components[@]}"
fi

if [[ "$skip_emacs" == false ]] && ! pacman -Q omarchy-emacs >/dev/null 2>&1; then
    # The official Omarchy route uses yay --needed without a full system update.
    command -v yay >/dev/null 2>&1 || { echo "setup-system: yay is required to install the omarchy-emacs AUR package" >&2; exit 1; }
    echo "Install Omarchy Emacs integration:"
    run omarchy pkg aur add omarchy-emacs
fi

if [[ "$dry_run" == false ]]; then
    verify_tools
    echo 'System prerequisites verified.'
fi
