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

Both templates create `* 概要` and place the cursor at the start of its body.

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
| C-c l    | Insert a link to an existing file or new title, without creating the target |
| C-c C-o  | Follow the link; a missing note opens with an unsaved summary template |
| C-x p i  | org-cliplink — insert org link from clipboard URL (fetches page title) |

### Conventions

- Filenames use underscores for spaces, first letter capitalized (e.g. `Binary_Hacks.org`)
- Changing `#+TITLE:` on save renames the file; existing mismatches are left alone on open.

### Links to future notes

`C-c l` accepts an existing filename or a new title (optional `.org` suffix).
For example, entering `new concept` inserts `[[file:New_concept.org][New concept]]`
when the source is in the vault root. Relative paths entered in the prompt are
relative to the vault root; the inserted link is relative to the current note.
Inserting the link never creates a file or directory.

Follow the link with `C-c C-o`, or click its red link in the live Web viewer to
open Emacs. `my/org-initialize-new-note` initializes only a nonexistent, empty
vault `.org` buffer with `#+TITLE:`, `#+DATE:`, and `* 概要`, leaving point ready
to write. The new file is created only when the user saves (`C-x C-s`). Existing
files, including empty files, and unsaved content are preserved. Capture opens
its targets with this initializer inhibited so its own template appears once.
Deft's new-note command reuses the initializer and keeps its existing save behavior.

### Title / Filename sync

Title edits synchronize on save; opening a note does not modify it.

- **Title changed on save** — file renames to match. Only links resolving to that exact file are rewritten; search suffixes and custom descriptions are preserved.
- **File renamed externally** (dired, shell, etc.) — run `M-x my/org-sync-filename-to-title` explicitly to adopt its filename and update links. It refuses ambiguous cases where the inferred old path still exists.
- Link changes to already modified buffers stay unsaved. Stale clean buffers must be reloaded before renaming, so their disk changes are not overwritten.
- Guard variable `my/org-sync-in-progress` prevents recursive triggering

### Backlinks

On saving a note, `my/org-sync-backlinks` compares outgoing links with the previous disk contents. It adds missing generated backlinks and removes entries for links deleted from that source. Generated Backlinks sections and example/source blocks do not count as outgoing links.

`my/org-ensure-backlink` and `my/org-remove-backlink` maintain the generated list and its count. They preserve user-written child sections and leave previously modified target buffers unsaved. Failed removals remain pending for a later save in the same buffer. Existing stale backlinks are not migrated in bulk.

### Regression tests

From the dotfiles repository root:

```sh
emacs --batch -Q -l emacs/tests/org-zettel-sync-tests.el -f ert-run-tests-batch-and-exit
```

The tests load only the relevant configuration forms, use disposable notes under `/tmp`, and reject note writes outside those fixtures.
