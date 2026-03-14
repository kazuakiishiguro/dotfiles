# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a stow module symlinked into `$HOME`.

## Repository layout

```
dotfiles/
  bash/           # .bashrc, .bash_profile
  bin/            # Custom scripts (~/.bin/)
  config/         # XDG configs: Hyprland, Ghostty, Kitty, i3, rofi
  emacs/          # Literate Emacs config (.emacs.d/*.org)
  git/            # .gitconfig, .gitconfig_fun, .gitignore_global
  screen/         # .screenrc
  scripts/        # OS-specific setup scripts, Brewfile, org-zettel
  shell/          # .shellrc (shared shell config sourced by bash & zsh)
  vim/            # .vimrc
  xinitrc/        # .xinitrc (Arch only)
  Xmodmap/        # .Xmodmap (Arch only)
  xprofile/       # .xprofile (Arch only)
  zsh/            # .zshrc, .zprofile
  bootstrap.sh    # One-liner setup for fresh machines
  init.sh         # Detects OS, runs setup, stows modules
```

## How stow modules work

`init.sh` runs `stow -t ~ -v <module>` for each module. Files inside a module directory mirror the home directory structure (e.g., `emacs/.emacs.d/init.el` becomes `~/.emacs.d/init.el`).

## Cross-platform support

Detected via `uname` in `init.sh`. OS-specific setup scripts live in `scripts/`:
- **macOS** — `setup_macos.sh` + `Brewfile`
- **Ubuntu** — `setup_ubuntu.sh`
- **Fedora** — `setup_fedora.sh`
- **Arch** — `setup_arch.sh` (also stows xinitrc, Xmodmap, xprofile)

## Shell config

Shared config (aliases, PATH, history, locale, GPG) lives in `shell/.shellrc`. Both `.bashrc` and `.zshrc` source `~/.shellrc`, then add shell-specific bits (bash: prompt, omarchy; zsh: vcs_info prompt, fzf, xcape).

## Hyprland (Arch)

Config is split into modular files under `config/.config/hypr/`:
- `hyprland.conf` — main entry, sources other files
- `bindings.conf` — keybindings
- `monitors.conf` — display layout
- `looknfeel.conf` — gaps, borders, animations
- `input.conf` — keyboard/mouse settings
- `autostart.conf` — startup applications
- `clamshell.conf` — laptop lid behavior
- `hypridle.conf` — idle/lock timeouts
- `hyprlock.conf` — lock screen appearance
- `hyprsunset.conf` — night light

## Org Zettelkasten Viewer (`scripts/org-zettel.*`)

A Scrapbox.io-style card grid viewer for the `~/org/` knowledge base. Symlinked into `~/org/` for use.

- `org-zettel.py` — Python script that scans `.org` files and either exports a static HTML viewer or runs a live HTTP server
- `org-zettel.html` — Single-file HTML/CSS/JS template (Flexoki color scheme, no frameworks)
- Static export: `cd ~/org && python3 org-zettel.py` → produces `org-zettel-view.html`
- Live server with editing: `cd ~/org && python3 org-zettel.py --serve` → serves on `localhost:8080`
- To run and open: `cd ~/org && python3 org-zettel.py --serve & sleep 1 && xdg-open http://127.0.0.1:8080`
- Server endpoints: `GET /api/health`, `GET /api/raw/{id}`, `POST /api/save/{id}`, plus static file serving for images
- Editing is Scrapbox-style: click content to enter raw org source textarea, click outside or Escape to save
- Data injection: Python replaces `const GRAPH_DATA = null;` in the template with JSON
- Pins stored in browser localStorage (key: `org-graph-pins`), separate per origin

## Conventions

- Keep stow module directories flat — mirror the target `$HOME` structure
- Emacs config changes go in the appropriate `.org` file, not raw `.el`
- OS-specific packages go in the corresponding `scripts/setup_*.sh`
- The `.gitignore` excludes compiled `.emacs.d/` artifacts except `init.el`, `custom.el`, and `*.org`
