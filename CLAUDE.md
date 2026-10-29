# Dotfiles

Personal dotfiles with a Stow-style source layout. The supported installer is
`./init.sh`, backed by Python's standard library; GNU Stow is not required.
Profiles decide which module files to apply and whether to link, copy or retain
each target. See `README.md` for the end-user commands.

## Repository layout

```
dotfiles/
  bash/           # .bashrc, .bash_profile
  bin/            # Custom scripts (~/.bin/)
  config/         # XDG configs: Hyprland, Ghostty, Kitty, i3, rofi
  emacs/          # Literate Emacs config and fixture-only ERT tests
  git/            # .gitconfig, .gitconfig_fun, .gitignore_global
  screen/         # .screenrc
  profiles/       # omarchy, linux, macos installation policies
  scripts/        # Installer implementation, dependencies, org-zettel, tests
  shell/          # .shellrc (shared shell config sourced by bash & zsh)
  vim/            # .vimrc
  xinitrc/        # .xinitrc (Arch only)
  Xmodmap/        # .Xmodmap (Arch only)
  xprofile/       # .xprofile (Arch only)
  zsh/            # .zshrc, .zprofile
  bootstrap.sh    # Clone/reuse ~/fun/dotfiles, then invoke init.sh
  init.sh         # Cwd-independent entry point for scripts/install.py
```

## Installation and machine profiles

Files inside module directories mirror `$HOME`. `scripts/install.py` selects
tracked and nonignored source files from the profile's modules, backs up
existing targets, and installs individual files. Runtime Emacs files are
excluded by an explicit allowlist. Do not reintroduce `stow --adopt`,
`git checkout .`, or other resets into installation or update hooks.

The Omarchy profile copies desktop-module `.config/**` and `.bashrc`, so Omarchy cannot change
repository sources by writing through installed symlinks. Shared desktop edits
must be made in the repository and applied with `./init.sh --config-only`.
The separately mapped Emacs source files remain symlinks under `~/.config/emacs`.
Existing monitor/fcitx5 settings are preserved. Idle/lock files, the old
post-update hook, app metadata and external-project systemd units are excluded.
`~/.config/hypr/local.lua` is a machine-owned override loaded after all shared
Hyprland modules. Keep local paths and application environment settings there;
never distribute that file from a shared profile.

Machine overrides in `~/.config/dotfiles/local.json` support four keys:
`modules` replaces the selected list; `exclude`, `preserve_existing` and `copy`
add path patterns to profile rules. Do not put host-specific paths or secrets
in shared profiles. Omarchy requires the standard `~/.config` location because
its packaged Emacs integration hardcodes that path.

`./init.sh --dry-run` must remain free of filesystem and package mutations.
`--skip-emacs` must leave all Emacs paths and packages untouched.
`--config-only` applies files without dependency installation or Emacs checks.
The normal flow is system prerequisites, configuration application, then
Emacs packages and validation. Reload a running daemon only for `--reload`.

`scripts/setup-system.sh` installs missing packages on Omarchy and dispatches
macOS provisioning to `scripts/setup-macos.sh`. Generic Linux remains
check-only. Do not add full upgrades, source builds or implicit Rust toolchain
switches. Bootstrap may install its own missing Git/Python prerequisites.
On Omarchy, a pre-existing plain `emacs` package must be replaced with
`emacs-wayland` interactively before normal provisioning. Check for that
conflict before installing any other packages.

macOS requires existing Homebrew and Xcode command line tools. Discover
Homebrew's ARM/Intel prefix when it is absent from PATH, and do not invoke
Apple's launcher stubs when developer tools are missing. `scripts/macos-env.sh`
supplies process-only Homebrew/Cargo/TeX paths to checkout entry points, keeping
explicit tool selections first without sourcing personal shell startup files.
Keep bootstrap and setup scripts compatible with the system Bash 3.2, including
empty arrays under `set -u`. Homebrew installation uses bottles and disables automatic
updates, target upgrades and cleanup. BasicTeX may request sudo interactively.
Existing working Emacs 29+ is retained; fresh installations get Homebrew's
`emacs-app` Cocoa cask, which supplies `emacs` and `emacsclient`. Alternative
GUI editions such as Emacs Plus remain an explicit user choice. Reject
broken/older installed editors before any package changes. Do not overwrite
an existing Emacs application just because its CLI command is absent from PATH.

Retain the active rustup toolchain and add only missing components, including
`rust-src`. Preserve working non-rustup toolchains as well. macOS Python editor
dependencies belong to `${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/python`,
never global Homebrew/Apple site-packages. Verify this environment directly;
Emacs selects it only on macOS without replacing project Python or downloading
anything during startup. `--skip-emacs` leaves this backend and Rust/TeX/font
dependencies untouched. The underscore `scripts/setup_macos.sh` is a safe
compatibility wrapper; the legacy Brewfile is not invoked. The older Arch,
Ubuntu, Fedora and Rust setup scripts are not used by `init.sh`.

Configuration backups are `~/.dotfiles-backup-*/` and logs are under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/`. A failed apply restores changed
files. Dependency failures retain completed work for the next run. Bootstrap
reuses an existing matching checkout without pulling or resetting it.

## Emacs setup

Keep sources under `emacs/.emacs.d/`. Omarchy maps selected files into
`~/.config/emacs/`, preserving managed Omarchy integration and backing up
conflicting legacy startup paths. Generic Linux/macOS use `~/.emacs.d/`.
Keep runtime data and generated files out of Git. Inspect both legacy and XDG
directories before migrating an existing Mac; do not silently deactivate
personal state in a pre-existing XDG setup.
Legacy-to-XDG migration carries the entire runtime tree into an absent target,
rebases symlinks and generated virtualenv launchers, and keeps originals in the
backup. Refuse ambiguous independent Emacs trees or replacement of personal
custom/snippet settings; do not silently deactivate them.

Declare package dependencies and authoritative VC recipes in `packages.el`.
Package acquisition belongs to `scripts/setup-emacs.sh`; regular startup must
remain network-free. Configuration checks use `check-config.el`. Preserve the
canonical Codex repository/recipe, the Transient preload before VC builds,
and safe interrupted-build recovery. See the nested Emacs `CLAUDE.md` for
editing and regression-test conventions.
Archive-to-VC changes preserve the previous archive in
`package-archive-backups/` after the new source package is verified, so a fresh
startup cannot accidentally select an older archive with a higher version.

Installer regression checks:

```sh
python3 -B -m unittest discover -s scripts/tests
node scripts/tests/test_org_zettel_render.cjs
emacs --batch -Q -l emacs/tests/setup-packages-tests.el -f ert-run-tests-batch-and-exit
```

On macOS, set `DOTFILES_TEST_BASH=/bin/bash` when running
`test_bootstrap.py` and `test_setup_macos.py` to exercise real Bash 3.2 semantics.
The macOS fixtures must never invoke real Homebrew or write outside temporary
homes, including when the test runner itself is a Mac.

## Shell config

Shared config (aliases, PATH, history, locale, GPG) lives in `shell/.shellrc`. Both `.bashrc` and `.zshrc` source `~/.shellrc`, then add shell-specific bits (bash: prompt, omarchy; zsh: vcs_info prompt, fzf, xcape).

Machine Git overrides belong in `~/.config/git/config`, included last by the
shared `.gitconfig`. Preserve local identity/signing choices and GPG agent
configuration; private keys are never distributed through this repository.

## Hyprland (Arch)

Omarchy migrated Hyprland to a **Lua-based config**. Hyprland runs with
`configProvider: lua`; the entry point is `hyprland.lua`, which `require()`s the
other modules. The old `.conf` files are gone — edit the `.lua` files. Apply
changes with `hyprctl reload` and check `hyprctl configerrors`.

Modular files under `config/.config/hypr/`:
- `hyprland.lua` — entry point; requires the modules below, holds personal rules
- `bindings.lua` — keybindings (`o.bind(...)`)
- `monitors.lua` — display layout / scale (`hl.monitor`, `hl.env`)
- `looknfeel.lua` — gaps, borders, animations (`hl.config`, `hl.animation`)
- `input.lua` — keyboard/touchpad (`kb_options = "ctrl:nocaps"`, `natural_scroll`)
- `autostart.lua` — startup apps (`o.launch_on_start`, `o.exec_on_start`)
- `.luarc.json` — Lua LSP hints for editing the above

Companion daemons keep their own `.conf` (not part of the Lua migration):
- `hypridle.conf` — idle/lock timeouts
- `hyprlock.conf` — lock screen appearance
- `hyprsunset.conf` — night light
- `xdph.conf` — xdg-desktop-portal-hyprland

Laptop lid (clamshell) is now handled by `omarchy-hyprland-monitor-watch`
(launched from `autostart.lua`), not a `clamshell.conf`. Input-method (fcitx)
env vars live in `config/.config/environment.d/fcitx.conf`, not `envs.conf`.

## Org Zettelkasten Viewer (`scripts/org-zettel.*`)

A Scrapbox.io-style card grid viewer for the `~/org/` knowledge base. Symlinked into `~/org/` for use.

- `org-zettel.py` — Python script that scans `.org` files and either exports a static HTML viewer or runs a live HTTP server
- `org-zettel.html` — Single-file HTML/CSS/JS template (Flexoki color scheme, no frameworks)
- Static export: `cd ~/org && python3 org-zettel.py` → produces `org-zettel-view.html`
- Live server with editing: `cd ~/org && python3 org-zettel.py --serve` → serves on `localhost:8080`
- To run and open: `cd ~/org && python3 org-zettel.py --serve & sleep 1 && xdg-open http://127.0.0.1:8080`
- On macOS use `open` instead of `xdg-open`. The Emacs button uses `emacsclient` to open a Cocoa frame; it requires a GUI Emacs edition and a desktop session. Homebrew's terminal-only Emacs cannot supply that frame.
- Server endpoints: `GET /api/health`, `GET /api/raw/{id}`, `POST /api/save/{id}`, `POST /api/open-emacs/{id}`, plus static file serving for images
- Inline editing is disabled by default; use the Emacs button to edit notes.
- Missing note links are red. Clicking one in the live viewer opens an unsaved Emacs buffer with the new-note template; the server does not create the file. Save in Emacs, then reload the viewer to refresh its graph and link colors.
- Graph data includes `file_ids` for all existing notes before display filters and `org_root` for absolute link resolution. Links use exact paths relative to their source note.
- Static exports show red links but cannot launch Emacs; that action requires the live server.
- Data injection: Python replaces `const GRAPH_DATA = null;` in the template with JSON
- Pins stored in browser localStorage (key: `org-graph-pins`), separate per origin

Backend regression tests use temporary vaults and mocked GUI launches:
`python3 -B -m unittest discover -s scripts/tests -p 'test_org_zettel.py'`

## Conventions

- Keep module files in the existing layout mirroring `$HOME`; profiles provide installation policy.
- Emacs feature changes go in the appropriate `.org` source; do not edit generated `.el` files.
- Keep package manifests/bootstrap logic in the explicit Emacs entry files; never download during startup.
- System dependencies belong to `scripts/setup-system.sh` and its macOS helper; installer internals belong under `scripts/`, daily commands under `bin/.bin/`.
- The `.gitignore` excludes runtime `.emacs.d/` data and allows only selected source/entry files and `*.org`.
- Installer tests must use temporary homes, checkouts and fake package managers; never modify the real desktop or download packages.
