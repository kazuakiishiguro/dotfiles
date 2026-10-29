# Emacs config

Literate config using org-babel. Sources stay in this directory, while the
installer maps selected files into `~/.config/emacs/` on Omarchy or
`~/.emacs.d/` on generic Linux/macOS. Use `user-emacs-directory` in Lisp rather
than hardcoded configuration paths.

`init.el` reports missing declared packages, then tangles and loads the shared
`.org` configuration so available features can still load:

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

Edit the appropriate `.org` source, then reload through the active directory:

```elisp
(org-babel-load-file (expand-file-name "org.org" user-emacs-directory))
```

Replace `org.org` with the changed module, or reload `init.el` to load them all.
Generated `.el` files live in the active configuration directory and are
regenerated from Org; do not edit or commit them. `custom.el` contains shared
preferences, while Customize writes machine changes to `custom-local.el`.

`packages.el` is the authoritative archive/VC package manifest, including the
canonical Codex recipe. Add new dependencies there and keep runtime
`use-package` declarations free of package downloads. Run `./init.sh` from the
repository to install system tools, install missing Emacs packages and verify
the full configuration. `scripts/setup-emacs.sh --config-dir DIR` handles only
Emacs packages/integration and validation; `--check-only` performs validation.
Reloading a running daemon is opt-in with `--reload`.

`early-init.el` contains early startup fixes. `check-config.el` validates shared
features. `shell-bashrc` adapts Omarchy shell integration without readline
bindings. Keep the Omarchy shim, theme, local package trees, caches and personal
notes on their host rather than copying them into this source directory.

Wayland clipboard integration (wl-paste/wl-copy) is in `general.org`, guarded by
`WAYLAND_DISPLAY` so it is skipped on macOS.

Machine-specific overrides belong in `local.el` inside the active Emacs
configuration directory. It is loaded after the shared configuration and must
not be committed. For example, an environment with Elpy's Python dependencies
already installed can opt in with `(setq elpy-rpc-virtualenv-path 'current)`.
Linux configuration keeps Elpy's default dedicated RPC environment. On macOS,
setup creates `${XDG_DATA_HOME:-~/.local/share}/dotfiles/python`; when available,
the shared configuration selects it for Elpy RPC and appends its tool directory
to PATH/exec-path, retaining project Python and project-specific tools first.
Do not create environments or install Python packages during Emacs startup.

On macOS GUI or daemon startup, `exec-path-from-shell` imports the shell's PATH before
other shared features load. Explicit setup installs it when needed; GUI startup
does not acquire packages. Linux, batch checks and ordinary terminal sessions
skip this initialization.

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
| c   | Clipping | `~/org/` | Reads URL through Emacs clipboard/kill-ring support, auto-derives title and link via org-cliplink |

Both templates create `* 概要` and place the cursor at the start of its body.

### Shared helpers

- **`my/org-title-to-path`** — core title-to-path logic: capitalizes first letter, replaces spaces with underscores, rejects duplicates, sets `my/capture-last-title`. Used by `my/capture-file` and `my/deft-new-note`
- **`my/capture-file`** — wraps `my/org-title-to-path` with a `read-string` prompt. Used by Note capture
- **`my/org-ensure-backlink`** — inserts a link under `* Backlinks (N)` in a target file, skipping duplicates and updating the count
- **`my/cliplink-capture-file`** — reads URL through Emacs clipboard/kill-ring support, fetches page title via `org-cliplink`, sets `my/capture-last-title` and `my/cliplink-last-link`, returns file path. Used by Clipping capture template

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
With Ivy, `RET` accepts the typed name even when it partially matches an existing
note. Select a candidate explicitly with `down` / `C-n`, then `RET`, or complete
it with `TAB`, to link to that existing note. This selection policy is local to
`C-c l`; other completion commands are unchanged.
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
emacs --batch -Q -l emacs/tests/setup-packages-tests.el -f ert-run-tests-batch-and-exit
```

Org tests load only relevant configuration forms, use disposable notes under
`/tmp`, and reject note writes outside those fixtures. Package tests use
temporary local Git repositories and verify interrupted builds, source-origin
checks and preservation of user edits without network access or existing
packages.
