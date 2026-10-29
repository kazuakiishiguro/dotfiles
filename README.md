# dotfiles

Shared shell, desktop and Emacs settings for several machines. Source modules
keep their Stow-style directory layout, but installation uses a small Python
standard-library installer; GNU Stow is not required.

The first supported shared setup is the two Omarchy 4.0 machines, using
Hyprland's Lua configuration and `emacs-wayland` with `omarchy-emacs`.
Linux and macOS profiles keep desktop configuration separate; automatic
application provisioning on those platforms is a later step.

## Setup

From an existing checkout:

```sh
cd ~/fun/dotfiles
./init.sh --dry-run
./init.sh
```

`init.sh` works from any directory. It selects `omarchy`, `linux` or `macos`
automatically; use `--profile NAME` to select one explicitly. On Omarchy the
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

Automatic application-package provisioning currently supports Omarchy. The
Linux and macOS profiles check prerequisites and report missing tools; install
those with the host's package manager, or use `--config-only` to apply settings
first. Emacs 29 or newer is required. The default Omarchy profile includes Rust
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

## What is shared

`profiles/*.json` select modules and installation policies. The Omarchy profile
copies desktop configuration and `.bashrc` into the home directory, so an
Omarchy update cannot write through their links into this checkout. Edit the
repository sources and rerun `./init.sh --config-only` to distribute a shared
change. Other selected files use individual symlinks.

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
The Linux and macOS profiles use `~/.emacs.d/`.
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
| `scripts/setup-system.sh` | Install missing system dependencies on Omarchy. |
| `scripts/setup-emacs.sh` | Install Emacs packages and validate configuration. |
| `bin/.bin/` | Commands used during normal daily work, not installer internals. |

Regression checks use disposable fixtures and do not install packages:

```sh
python3 -B -m unittest discover -s scripts/tests
node scripts/tests/test_org_zettel_render.cjs
emacs --batch -Q -l emacs/tests/setup-packages-tests.el -f ert-run-tests-batch-and-exit
emacs --batch -Q -l emacs/tests/org-zettel-sync-tests.el -f ert-run-tests-batch-and-exit
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
