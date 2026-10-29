#!/usr/bin/env bash
# Missing-only macOS prerequisites. Keep existing editors and Rust toolchains.
set -euo pipefail

skip_emacs=false
dry_run=false
while (($#)); do
    case "$1" in
        --skip-emacs) skip_emacs=true; shift ;;
        --dry-run) dry_run=true; shift ;;
        -h|--help)
            echo 'Usage: setup-macos.sh [--skip-emacs] [--dry-run]'
            exit 0 ;;
        *) echo "setup-macos: unknown argument: $1" >&2; exit 2 ;;
    esac
done

fail() {
    printf 'setup-macos: %s\n' "$*" >&2
    exit 1
}

run() {
    printf '  '
    printf '%q ' "$@"
    printf '\n'
    [[ "$dry_run" == true ]] || "$@"
}

tool_works() {
    command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1
}

[[ "$(uname -s)" == Darwin ]] || fail 'this helper requires macOS'
# Check this before invoking Apple's Git/Python/LLDB launcher stubs.
if ! developer_directory=$(xcode-select -p 2>/dev/null) || [[ ! -d "$developer_directory" ]]; then
    fail 'install the Xcode command line tools with xcode-select --install, then rerun'
fi
if ! command -v brew >/dev/null 2>&1; then
    for brew_prefix in /opt/homebrew /usr/local; do
        if [[ -x "$brew_prefix/bin/brew" ]]; then
            export PATH="$brew_prefix/bin:$brew_prefix/sbin:$PATH"
            break
        fi
    done
fi
tool_works brew || fail 'install Homebrew first: https://brew.sh/'
# The active rustup toolchain and MacTeX are not always in an SSH shell's PATH.
if ! command -v cargo >/dev/null 2>&1 && ! command -v rustup >/dev/null 2>&1 &&
   [[ -x "$HOME/.cargo/bin/rustup" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi
export PATH="$PATH:/Library/TeX/texbin"

formulae=()
casks=()
rustup_components=()
emacs_binary="${EMACS:-emacs}"
python_environment="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/python"
python_backend="$python_environment/bin/python"

need_formula() {
    local formula="$1" executable="$2"
    tool_works "$executable" && return 0
    if brew list --formula --versions "$formula" >/dev/null 2>&1; then
        fail "$formula is installed, but $executable is unavailable or broken. Repair it or adjust PATH, then rerun; no packages were changed."
    fi
    formulae+=("$formula")
}

need_cask() {
    brew list --cask --versions "$1" >/dev/null 2>&1 || casks+=("$1")
}

emacs_works() {
    local major
    major=$("$emacs_binary" --batch -Q --eval '(princ emacs-major-version)' 2>/dev/null) || return 1
    case "$major" in ''|*[!0-9]*) return 1 ;; esac
    ((major >= 29))
}

# Complete all conflict checks before the first package installation.
if [[ "$skip_emacs" == false ]]; then
    if command -v "$emacs_binary" >/dev/null 2>&1; then
        emacs_works || fail "existing Emacs ($emacs_binary) cannot run Emacs 29 or newer. Repair/select your editor, or use --skip-emacs; it was not replaced."
    elif [[ -n "${EMACS:-}" ]]; then
        fail "the selected EMACS executable is unavailable: $EMACS"
    elif brew list --formula --versions emacs >/dev/null 2>&1; then
        fail 'Homebrew emacs is installed but unavailable in PATH. Link/select it explicitly before rerunning.'
    elif brew list --cask --versions emacs-app >/dev/null 2>&1 ||
         [[ -e "/Applications/Emacs.app" || -L "/Applications/Emacs.app" ||
            -e "$HOME/Applications/Emacs.app" || -L "$HOME/Applications/Emacs.app" ]]; then
        fail 'An Emacs application already exists, but emacs is unavailable in PATH. Select its executable explicitly before rerunning; the application was not replaced.'
    else
        # The Homebrew Cocoa cask supplies Emacs and emacsclient without a
        # source build, including GUI frames used by the Org viewer.
        casks+=(emacs-app)
    fi

    if command -v rustup >/dev/null 2>&1; then
        rustup show active-toolchain >/dev/null 2>&1 ||
            fail 'rustup has no working active toolchain. Select one explicitly with rustup, then rerun; no toolchain was switched.'
        if ! tool_works cargo || ! tool_works rustc; then
            fail 'the selected rustup toolchain cannot run cargo/rustc. Repair it before rerunning; no toolchain was switched.'
        fi
        tool_works rustfmt || rustup_components+=(rustfmt)
        tool_works rust-analyzer || rustup_components+=(rust-analyzer)
        cargo clippy --version >/dev/null 2>&1 || rustup_components+=(clippy)
        rust_sources=false
        while IFS= read -r component; do
            [[ "$component" != rust-src ]] || rust_sources=true
        done < <(rustup component list --installed)
        [[ "$rust_sources" == true ]] || rustup_components+=(rust-src)
    elif command -v cargo >/dev/null 2>&1 || command -v rustc >/dev/null 2>&1; then
        if ! tool_works cargo || ! tool_works rustc || ! tool_works rustfmt ||
           ! cargo clippy --version >/dev/null 2>&1; then
            fail 'the existing non-rustup Rust toolchain is incomplete or broken. Repair it before rerunning; it was not replaced.'
        fi
        need_formula rust-analyzer rust-analyzer
    else
        need_formula rust rustc
        need_formula rust-analyzer rust-analyzer
    fi
    tool_works lldb || fail 'LLDB is unavailable. Repair the Xcode command line tools before rerunning.'
    if [[ -e "$python_environment" || -L "$python_environment" ]] &&
       { [[ ! -f "$python_environment/pyvenv.cfg" ]] || ! tool_works "$python_backend"; }; then
        fail "the managed Python environment is invalid: $python_environment. Inspect or relocate it before rerunning; it was not overwritten."
    fi
    if ! tool_works pdflatex; then
        for tex_cask in basictex mactex mactex-no-gui; do
            if brew list --cask --versions "$tex_cask" >/dev/null 2>&1; then
                fail "$tex_cask is installed, but pdflatex is unavailable or broken. Repair the TeX installation before rerunning."
            fi
        done
        casks+=(basictex)
    fi
    need_formula pandoc pandoc
    need_cask font-jetbrains-mono-nerd-font
fi
need_formula git git
need_formula python python3
need_formula curl curl
need_formula fzf fzf
need_formula gnupg gpg

# Disable automatic updates/upgrades/cleanup; requested missing dependencies
# can still bring in their own required Homebrew dependencies.
if ((${#formulae[@]})); then
    echo 'Missing Homebrew formulae:'
    run env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 \
        brew install --formula --force-bottle "${formulae[@]}"
fi
if ((${#casks[@]})); then
    echo 'Missing Homebrew casks (BasicTeX may request administrator authentication):'
    run env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 \
        brew install --cask "${casks[@]}"
fi
if ((${#rustup_components[@]})); then
    echo 'Missing components in the existing rustup toolchain:'
    run rustup component add "${rustup_components[@]}"
fi

if [[ "$skip_emacs" == false ]]; then
    if [[ ! -e "$python_environment" && ! -L "$python_environment" ]]; then
        echo "Create the dotfiles Python backend: $python_environment"
        run python3 -m venv "$python_environment"
    fi
    missing_python=()
    for module in jedi rope flake8 black; do
        if ! "$python_backend" -B -c "import $module" >/dev/null 2>&1; then
            missing_python+=("$module")
        fi
    done
    if ((${#missing_python[@]})); then
        echo 'Missing packages in the dotfiles Python backend:'
        run "$python_backend" -m pip install --disable-pip-version-check "${missing_python[@]}"
    fi
fi

if [[ "$dry_run" == true ]]; then
    echo 'macOS prerequisite preview complete; no packages or files changed.'
    exit 0
fi
for executable in git python3 curl fzf gpg; do
    tool_works "$executable" || fail "prerequisite is unavailable or broken after installation: $executable"
done
if [[ "$skip_emacs" == false ]]; then
    emacs_works || fail "Emacs 29 or newer is still unavailable: $emacs_binary"
    for executable in cargo rustc rustfmt rust-analyzer lldb pdflatex pandoc; do
        tool_works "$executable" || fail "prerequisite is unavailable or broken after installation: $executable"
    done
    cargo clippy --version >/dev/null 2>&1 || fail 'cargo clippy is still unavailable'
    "$python_backend" -B -c 'import jedi, rope, flake8, black' || fail 'the dotfiles Python backend is incomplete'
    tool_works "$python_environment/bin/black" || fail 'the dotfiles black executable is unavailable'
    tool_works "$python_environment/bin/flake8" || fail 'the dotfiles flake8 executable is unavailable'
fi
echo 'macOS system prerequisites verified.'
