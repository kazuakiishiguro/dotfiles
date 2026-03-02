# Emacs config

Literate config using org-babel. `init.el` tangles and loads `.org` files:

| File                | Purpose                              |
|---------------------|--------------------------------------|
| `configuration.org` | Main entry — loads other org files   |
| `general.org`       | Core settings, packages, completion  |
| `ui.org`            | Appearance, fonts, theme             |
| `org.org`           | Org-mode (capture, agenda, backlinks)|
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

---

## Org vault

Kepano-inspired personal knowledge base managed via Emacs org-mode. Data lives in `~/org/`, config lives in `org.org`.

### Directory structure

```
~/org/
  Daily/          # Daily anchor files (YYYY-MM-DD.org)
  References/     # Books, people, tools, protocols
  Clippings/      # Saved external essays/articles
  .categories     # Auto-generated category list (do not edit manually)
  todo.org        # Task inbox
  archive.org     # Archived tasks
```

### Capture templates (C-c c)

| Key | Name          | Target        | Notes                                           |
|-----|---------------|---------------|-------------------------------------------------|
| t   | TODO          | `todo.org`    | Standard task entry                             |
| n   | Note          | `~/org/`      | Prompts for title, links to today's Daily, adds backlink in Daily file |
| r   | Reference     | `References/` | Prompts for title + category from `.categories` |
| K   | Category      | `~/org/`      | Creates file with `#+TYPE: category`            |
| c   | Clipping      | `Clippings/`  | Auto-tagged `:Manuscripts:`, reads URL from clipboard via wl-paste, auto-derives title and link via org-cliplink |
| w   | Weekly review | `~/org/`      | Auto-named `WeekNN_-_Mon_YYYY.org`              |

### Shared helpers

- **`my/org-title-to-path`** — core title-to-path logic: capitalizes first letter, replaces spaces with underscores, rejects duplicates, sets `my/capture-last-title`. Used by `my/capture-file` and `my/deft-new-note`
- **`my/capture-file`** — wraps `my/org-title-to-path` with a `read-string` prompt. Used by capture templates (except TODO and Weekly)
- **`my/org-add-daily-backlink`** — ensures today's daily file exists (with headers) and adds a backlink to the given note. Used by `my/org-capture-add-daily-backlink` and `my/deft-new-note`
- **`my/org-ensure-backlink`** — inserts a link under `* Backlinks (N)` in a target file, skipping duplicates and updating the count
- **`my/cliplink-capture-file`** — reads URL from clipboard via `wl-paste`, fetches page title via `org-cliplink`, sets `my/capture-last-title` and `my/cliplink-last-link`, returns file path in `Clippings/`. Used by Clipping capture template

### Category system

- A file becomes a category by having `#+TYPE: category` in its header
- `my/sync-reference-categories` runs on every save of any `.org` file under `~/org/`
- It scans all org files for `#+TYPE: category` and writes filenames to `.categories`
- `my/select-categories` is the shared multi-select helper (completing-read loop with `[done]` sentinel)
- Both Reference capture (`r`) and `C-c t` use `my/select-categories`
- To add a new category: `C-c c K` or manually add `#+TYPE: category` to any file

### Search

`M-x deft` opens a live-filtering buffer that searches both filenames and content across all `.org` files under `~/org/` (recursive). Typing instantly narrows results. Toggle regexp mode with `C-c C-t`. Press `C-c C-n` to create a new note from the current search term (same behavior as Note capture: capitalizes title, links to daily, adds daily backlink).

### Org keybindings

| Binding     | Action                  |
|-------------|-------------------------|
| M-x deft    | Search files and content in org vault |
| C-c C-n     | (in Deft) Create note from search term |
| C-c a       | org-agenda              |
| C-c c       | org-capture             |
| C-c n       | Start Note capture (prompts for title) |
| C-c l       | Insert org file link (completing-read from vault, description from filename) |
| C-x p i     | org-cliplink — insert org link from clipboard URL (fetches page title) |
| C-c t       | Set #+FILETAGS from .categories (+ backlinks in category files) |
| C-c C-x C-s | Mark done and archive   |

Note: `my/org-daily-file` (open today's daily file) is defined but not bound to a key.

### Org conventions

- Filenames use underscores for spaces, first letter capitalized (e.g. `Binary_Hacks.org`)
- `#+TITLE:` always matches the filename (enforced automatically — see Title/Filename sync below)
- `#+FILETAGS:` uses colon-delimited tags (e.g. `:読書ログ:`)
- `#+TYPE: category` is a custom keyword, not a standard org property
- Daily files are named `YYYY-MM-DD.org` in `Daily/`
- Weekly reviews are named `WeekNN_-_Mon_YYYY.org` in root

### Title / Filename sync

Title and filename are kept in sync automatically. Daily and weekly files are excluded.

- **Title changed on save** — file renames to match, all `[[file:...]]` links and descriptions across the vault are updated
- **File renamed externally** (dired, shell, etc.) — on next open, `#+TITLE:` updates to match filename, backlinks are updated
- Guard variable `my/org-sync-in-progress` prevents recursive triggering

### Backlinks

Backlinks are managed via `my/org-ensure-backlink`, which inserts links under a `* Backlinks (N)` heading (created if absent) and keeps the count updated. Duplicates are skipped.

Three triggers create backlinks automatically (all via `my/org-add-daily-backlink` or `my/org-ensure-backlink`):

- **Note capture** (`C-c c n`) or **Deft new note** (`C-c C-n`) — backlink added in today's Daily file
- **Setting filetags** (`C-c t`) — backlink added in each selected category file
- **Saving any org file** — all `[[file:...]]` links in the buffer are scanned; backlinks are created in each linked file (category files are excluded as sources to avoid noise)
