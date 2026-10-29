# dotfiles

Shared shell, desktop and Emacs settings for several machines. Source modules
keep their Stow-style directory layout, but installation uses a small Python
standard-library installer; GNU Stow is not required.

Omarchy 4.0 and macOS share shell, Git and Emacs sources while retaining their
own desktop settings. Omarchy uses Hyprland's Lua configuration and
`emacs-wayland` with `omarchy-emacs`. Both profiles can install missing
dependencies; the generic Linux profile checks prerequisites only.

## Setup

From an existing checkout:

```sh
cd ~/fun/dotfiles
./init.sh --dry-run
./init.sh
```

`init.sh` works from any directory. It selects `omarchy`, `linux` or `macos`
automatically; use `--profile NAME` to select one explicitly. On Omarchy and macOS the
normal run installs missing system tools, applies configuration, installs
missing Emacs packages and validates the full Emacs configuration. Run it in a
normal terminal with network access so the package manager can request sudo.
It does not upgrade the whole system or reset the checkout.

| Option | Effect |
| --- | --- |
| `--dry-run` | Show planned files and missing system packages without writing or installing anything. |
| `--config-only` | Apply configuration without system or Emacs package installation or Emacs validation. |
| `--skip-emacs` | Leave all Emacs paths and packages untouched. |
| `--reload` | Reload a running Emacs daemon after successful Emacs validation; otherwise changes take effect on its next start. |
| `--profile omarchy\|linux\|macos` | Choose the machine profile. |
| `--local PATH` | Read machine overrides from a different JSON file. |

The generic Linux profile reports missing prerequisites; install those with
the host's package manager, or use `--config-only` to apply settings first.
Emacs 29 or newer is required. The Omarchy and macOS profiles include Rust
tools, Python tools (`jedi`, `rope`, `flake8`, `black`), Pandoc and LaTeX.
If an Omarchy host has Arch's plain `emacs` package, replace it interactively
with `sudo pacman -S emacs-wayland` before normal setup. The installer detects
this conflict before changing packages. `--skip-emacs` retains that editor.

For a fresh machine, the remote command below uses the version published on
GitHub's `master` branch. Local changes must be committed and pushed before
that command can install them; use the checkout commands above until then.

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/kazuakiishiguro/dotfiles/master/bootstrap.sh)
```

Bootstrap defaults to `~/fun/dotfiles`. It reuses an existing checkout of this
repository without pulling or resetting it. A different location and all
installer options can be supplied:

```sh
bash bootstrap.sh --dir "$HOME/fun/dotfiles" --profile omarchy --dry-run
```

## macOS

Install Apple's Xcode command line tools (`xcode-select --install`) and
[Homebrew](https://brew.sh/) first. After those prerequisites, the bootstrap
command above or a single `./init.sh` from the checkout handles the remaining
setup. Bootstrap discovers Homebrew under `/opt/homebrew` or `/usr/local`,
including in SSH sessions, and checks that Git and Python actually run.
Missing Apple developer tools are reported without opening an installer dialog
during a dry run.

`init.sh` and the Emacs setup entry point also discover Homebrew, Cargo and TeX
paths through `scripts/macos-env.sh`. This changes only the installer process's
environment, keeps explicitly selected tools first, and does not source
personal shell startup files.

macOS provisioning installs missing tools through Homebrew without running a
general update, upgrade or cleanup. Formulae use bottles; an unavailable bottle
must be resolved explicitly rather than triggering a source build. BasicTeX
provides `pdflatex` and may require administrator authentication. The installer
also adds the configured JetBrains Mono Nerd Font when its cask is absent.

A working existing Emacs 29 or newer is retained, including GUI editions. A
fresh installation gets the Cocoa GUI from Homebrew's
[`emacs-app` cask](https://formulae.brew.sh/cask/emacs-app), including its
`emacs` and `emacsclient` commands. An alternative GUI edition such as
[Emacs Plus](https://github.com/d12frosted/homebrew-emacs-plus#install) can be
installed separately using its maintained instructions before dotfiles setup.
Broken or older existing editors stop provisioning before package changes;
repair/select the editor or use `--skip-emacs` to continue without it.
An existing Emacs application without a command in `PATH` also requires
explicit selection; the installer does not overwrite it.
The Org viewer's Emacs button on macOS requires a Cocoa-capable Emacs and its
`emacsclient` in `PATH`, since it opens a GUI frame. A retained terminal-only
Emacs supports terminal editing but cannot create that frame.

An existing rustup toolchain stays selected; only missing `rustfmt`, Clippy,
`rust-analyzer` and `rust-src` components are added. A working non-rustup
toolchain is also retained. Fresh hosts without Rust receive the Homebrew
Rust tools. An incomplete existing toolchain must be repaired explicitly.

Python editor tools live in a dedicated virtual environment at
`${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/python`. Nothing is installed into
Homebrew's or Apple's global Python environment. The macOS Emacs configuration
uses this environment for Elpy and offers its formatter/checker commands as
fallbacks, retaining project Python and project-specific tools. `--skip-emacs`
also skips this environment, Rust, LaTeX and the editor font.

The older `scripts/setup_macos.sh` name delegates to the new
`scripts/setup-macos.sh` helper. The legacy `scripts/Brewfile` is not used by
either entry point.

## What is shared

`profiles/*.json` select modules and installation policies. The Omarchy profile
copies desktop configuration and `.bashrc` into the home directory, so an
Omarchy update cannot write through their links into this checkout. Edit the
repository sources and rerun `./init.sh --config-only` to distribute a shared
change. Other selected files use individual symlinks.

Keep machine-specific Git identity, signing program and key choices in
`~/.config/git/config`. The shared `.gitconfig` includes it last, so those
settings override the shared defaults. Existing local GPG configuration and
private keys remain on the machine.

Existing monitor and fcitx5 settings are retained on each PC. The Omarchy
profile excludes idle/lock configuration, input-method environment settings,
the old post-update hook, Copilot version metadata, i3/rofi configuration and
systemd units that depend on external projects. Those files can remain in the
repository without being applied to every machine.

Put additional Hyprland settings specific to one machine in
`~/.config/hypr/local.lua`. The shared entry point loads it last when present;
the installer does not distribute or overwrite it. Move personal additions
out of `hyprland.lua` before applying a shared update. Monitor settings remain
in the preserved `monitors.lua`; input devices or local application environment
settings can be overridden in `local.lua`.

Machine overrides live in `~/.config/dotfiles/local.json`, outside the shared
repository. For example:

```json
{
  "exclude": [".config/hypr/bindings.lua"],
  "preserve_existing": [".config/ghostty/config"]
}
```

Paths are relative to the home directory and accept glob patterns. `exclude`,
`preserve_existing` and `copy` add rules to the selected profile; `modules`
replaces its module list when supplied. `preserve_existing` applies the source
only when the target is absent. On Omarchy, use the standard `~/.config`
location because the packaged Emacs integration does not support a custom
`XDG_CONFIG_HOME`.

## Emacs and repeat runs

The source remains under `emacs/.emacs.d/`. Omarchy installs its shared files
into `~/.config/emacs/`, retaining the package-managed Omarchy theme and shim.
Conflicting legacy startup files such as `~/.emacs` and `~/.emacs.d` are backed
up before that migration. When the XDG directory is absent, the full legacy
directory is carried over, including packages, bookmarks, histories and local
settings. Relocated symlinks and generated virtualenv launchers are adjusted;
the original tree remains in the backup. Two independent existing Emacs
directories require manual consolidation before installation continues.
The Linux and macOS profiles use `~/.emacs.d/`; consolidate any existing XDG
Emacs setup before applying these profiles for the first time.
Installed packages, generated Lisp files, compiler caches, backups and
`custom-local.el` stay on the machine.

Before replacing a personal `custom.el`, move its settings to
`custom-local.el`; keep personal snippets with a `preserve_existing` rule or
exclude that path. The installer stops before overwriting these local settings
when they differ from the shared source.

Package sources are declared in `packages.el`; ordinary Emacs startup never
downloads packages. Repeat `./init.sh` after an interrupted installation.
Completed packages are reused, and source checkouts from interrupted builds
are rebuilt only after their origin and local source changes are checked.
When a declared source package replaces an archive package, the old archive is
moved into `package-archive-backups/` only after the source build succeeds.
Archive packages currently use the available ELPA/MELPA versions rather than
a version lock. This workflow provides repeatable installation steps, not
identical package versions across installation dates.

To check an already installed Omarchy Emacs configuration:

```sh
./scripts/setup-emacs.sh --config-dir "$HOME/.config/emacs" --check-only
```

On macOS, use `--config-dir "$HOME/.emacs.d"` instead.

Without `--check-only`, this script installs Emacs packages and then validates
them. System-tool installation belongs to `./init.sh`; the Emacs script does
not install Python or Rust tools. The former `emacs-setup --packages-only`
option is accepted for compatibility. A running Emacs daemon is reloaded only
when `--reload` is explicitly requested.
The existing local `dotfiles-apply` helper delegates to `scripts/apply-config.sh`:
it previews by default and accepts `--apply` to run `init.sh --config-only`.
Neither convenience command is required for a fresh installation.

Logs are written to `~/.local/state/dotfiles/` (or `$XDG_STATE_HOME/dotfiles`).
Configuration backups live in `~/.dotfiles-backup-*/`, with an inventory in
`manifest.json`. A configuration-application failure restores files it changed;
a later package failure retains the applied configuration and installed
packages so the same command can resume. Review backups before deleting them;
logs and backups are not required for normal Emacs operation.

Account login, AI-service authentication, GPG private keys and personal data
are not provisioned by this repository.
Legacy `pass`, `pass-fzf` and `passage-fzf` wrappers are no longer distributed.

## Installer structure

| Path | Responsibility |
| --- | --- |
| `bootstrap.sh` | Obtain/reuse the checkout and its Git/Python prerequisites. |
| `init.sh`, `scripts/install.py` | Select a profile, back up files, apply configuration and run setup phases. |
| `profiles/` | Shared installation policy; per-PC overrides stay outside Git. |
| `scripts/setup-system.sh` | Install Omarchy dependencies, dispatch macOS setup or check generic Linux prerequisites. |
| `scripts/setup-macos.sh` | Install missing Homebrew dependencies and the dedicated Python backend. |
| `scripts/macos-env.sh` | Supply process-local macOS tool paths to checkout entry points. |
| `scripts/setup-emacs.sh` | Install Emacs packages and validate configuration. |
| `bin/.bin/` | Commands used during normal daily work, not installer internals. |

Regression checks use disposable fixtures and do not install packages:

```sh
python3 -B -m unittest discover -s scripts/tests
node scripts/tests/test_org_zettel_render.cjs
emacs --batch -Q -l emacs/tests/setup-packages-tests.el -f ert-run-tests-batch-and-exit
emacs --batch -Q -l emacs/tests/org-zettel-sync-tests.el -f ert-run-tests-batch-and-exit
```

On a Mac, exercise bootstrap and provisioning with the system Bash 3.2:

```sh
DOTFILES_TEST_BASH=/bin/bash python3 -B -m unittest discover -s scripts/tests -p test_bootstrap.py
DOTFILES_TEST_BASH=/bin/bash python3 -B -m unittest discover -s scripts/tests -p test_setup_macos.py
```

## Signed commits in remote Magit

`gpg-for-git` uses GnuPG's loopback mode when Magit runs inside an SSH
session. Magit then asks for the passphrase in the Emacs minibuffer, avoiding
terminal pinentry drawing over Emacs. Local commits keep the usual pinentry
dialog, and shell commits keep the usual GPG behavior.

After updating the remote dotfiles checkout, apply its selected configuration:

```sh
./init.sh --config-only
```

`~/.bin` must be in `PATH` (provided by this repository's `.shellrc`). This
requires GnuPG 2.1 or later and loopback pinentry to be allowed by the agent
(the default). If `~/.gnupg/gpg-agent.conf` contains `no-allow-loopback-pinentry`,
replace it with `allow-loopback-pinentry` and run `gpgconf --reload gpg-agent`.
