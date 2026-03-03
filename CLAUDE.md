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
  scripts/        # OS-specific setup scripts + Brewfile
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

## Conventions

- Keep stow module directories flat — mirror the target `$HOME` structure
- Emacs config changes go in the appropriate `.org` file, not raw `.el`
- OS-specific packages go in the corresponding `scripts/setup_*.sh`
- The `.gitignore` excludes compiled `.emacs.d/` artifacts except `init.el`, `custom.el`, and `*.org`
