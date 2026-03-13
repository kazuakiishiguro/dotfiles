# Emacs config

Literate config using org-babel. `init.el` tangles and loads `.org` files:

| File                | Purpose                              |
|---------------------|--------------------------------------|
| `configuration.org` | Main entry — loads other org files   |
| `general.org`       | Core settings, packages, completion  |
| `ui.org`            | Appearance, fonts, theme             |
| `org.org`           | Org-mode (capture, backlinks)        |
| `prog.org`          | General programming (LSP, etc.)      |
| `claude.org`        | Claude.com / Claude Code IDE integration |
| `c.org`             | C language                           |
| `rust.org`          | Rust                                 |
| `python.org`        | Python                               |
| `markdown.org`      | Markdown                             |

After editing any `.org` config, reload with:
```elisp
(delete-file "~/.emacs.d/<name>.el")
(org-babel-load-file "~/.emacs.d/<name>.org")
```

Wayland clipboard integration (wl-paste/wl-copy) is in `general.org`, guarded by `WAYLAND_DISPLAY` so it's skipped on macOS.

Literate config source: `~/fun/dotfiles/emacs/.emacs.d/org.org`. Compiled output: `~/.emacs.d/org.el`. Edit both when changing config.

---

## Org vault

Personal knowledge base managed via Emacs org-mode. Data lives in `~/org/`, config lives in `org.org`.

### Directory structure

```
~/org/          # All .org files live flat here (no subdirectories)
```

### Capture templates (C-c c)

| Key | Name     | Target   | Notes                                                                 |
|-----|----------|----------|-----------------------------------------------------------------------|
| n   | Note     | `~/org/` | Prompts for title, creates file via `my/capture-file`                 |
| c   | Clipping | `~/org/` | Reads URL from clipboard via wl-paste, auto-derives title and link via org-cliplink |

### Shared helpers

- **`my/org-title-to-path`** — core title-to-path logic: capitalizes first letter, replaces spaces with underscores, rejects duplicates, sets `my/capture-last-title`. Used by `my/capture-file` and `my/deft-new-note`
- **`my/capture-file`** — wraps `my/org-title-to-path` with a `read-string` prompt. Used by Note capture
- **`my/org-ensure-backlink`** — inserts a link under `* Backlinks (N)` in a target file, skipping duplicates and updating the count
- **`my/cliplink-capture-file`** — reads URL from clipboard via `wl-paste`, fetches page title via `org-cliplink`, sets `my/capture-last-title` and `my/cliplink-last-link`, returns file path. Used by Clipping capture template

### Search

`M-x deft` opens a live-filtering buffer that searches both filenames and content across all `.org` files under `~/org/` (recursive). Typing instantly narrows results. Toggle regexp mode with `C-c C-t`. Press `C-c C-n` to create a new note from the current search term.

### Keybindings

| Binding  | Action                                                              |
|----------|---------------------------------------------------------------------|
| M-x deft | Search files and content in org vault                               |
| C-c C-n  | (in Deft) Create note from search term                              |
| C-c c    | org-capture                                                         |
| C-c n    | Start Note capture (prompts for title)                              |
| C-c l    | Insert org file link (completing-read from vault, description from filename) |
| C-x p i  | org-cliplink — insert org link from clipboard URL (fetches page title) |

### Conventions

- Filenames use underscores for spaces, first letter capitalized (e.g. `Binary_Hacks.org`)
- `#+TITLE:` always matches the filename (enforced automatically — see Title/Filename sync below)

### Title / Filename sync

Title and filename are kept in sync automatically.

- **Title changed on save** — file renames to match, all `[[file:...]]` links and descriptions across the vault are updated
- **File renamed externally** (dired, shell, etc.) — on next open, `#+TITLE:` updates to match filename, backlinks are updated
- Guard variable `my/org-sync-in-progress` prevents recursive triggering

### Backlinks

Backlinks are the sole linking mechanism. Managed via `my/org-ensure-backlink`, which inserts links under a `* Backlinks (N)` heading (created if absent) and keeps the count updated. Duplicates are skipped.

One trigger creates backlinks automatically:

- **Saving any org file** — all `[[file:...]]` links in the buffer are scanned; backlinks are created in each linked file
