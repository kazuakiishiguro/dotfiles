#!/usr/bin/env python3
"""Apply shared dotfiles, with protected machine settings and resumable setup."""

import argparse
import datetime
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


REPO = Path(__file__).resolve().parent.parent
EMACS_FILES = {
    "init.el", "early-init.el", "custom.el", "packages.el", "check-config.el",
    "shell-bashrc",
}
LEGACY_EMACS = (".emacs", ".emacs.el", ".emacs.elc", ".emacs.d")


def exists(path):
    return path.exists() or path.is_symlink()


def matches(path, patterns):
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)


def relative_path(value):
    path = Path(value)
    if not value or path.is_absolute() or ".." in path.parts or path == Path("."):
        raise ValueError(f"Expected a path relative to HOME: {value!r}")
    return path


def load_profile(repo, name, local):
    profile = json.loads((repo / "profiles" / f"{name}.json").read_text())
    if local.is_file():
        override = json.loads(local.read_text())
        unknown = set(override) - {"modules", "exclude", "preserve_existing", "copy"}
        if unknown:
            raise ValueError(f"Unknown local profile keys: {sorted(unknown)}")
        for key, value in override.items():
            if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
                raise ValueError(f"Profile {key} must be a list of strings")
            profile[key] = value if key == "modules" else profile[key] + value
    for module in profile["modules"]:
        if "/" in module or module in (".", "..") or not (repo / module).is_dir():
            raise ValueError(f"Unknown module: {module!r}")
    return profile


def check_parents(target, home, materialize=None):
    for parent in target.parents:
        if parent == home:
            return
        if materialize is not None and (parent == materialize or materialize in parent.parents):
            continue
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            raise ValueError(f"Target parent must be a real directory: {parent}")
    raise ValueError(f"Target is outside HOME: {target}")


def emacs_directory_source(home, target):
    """Resolve the old directory before its link or legacy name is moved."""
    source = target if target.is_symlink() else home / ".emacs.d"
    if not source.is_dir():
        raise ValueError(f"Emacs state must be a directory: {source}")
    resolved = source.resolve(strict=True)
    if resolved == target or resolved in target.parents:
        raise ValueError(f"Cannot migrate Emacs state from a parent of its target: {source}")
    return resolved


def same_directory_contents(left, right):
    """Compare snippet trees without following nonmatching directory links."""
    if left.is_symlink() or right.is_symlink():
        return left.resolve() == right.resolve()
    if left.is_dir() and right.is_dir():
        left_files = {path.name: path for path in left.iterdir()}
        right_files = {path.name: path for path in right.iterdir()}
        return (left_files.keys() == right_files.keys()
                and all(same_directory_contents(path, right_files[name])
                        for name, path in left_files.items()))
    return left.is_file() and right.is_file() and left.read_bytes() == right.read_bytes()


def check_emacs_local_settings(name, source, existing_root):
    """Require an explicit resolution before replacing personal Lisp/snippets."""
    existing = existing_root / name
    if name == "custom.el" and existing.is_file() and existing.read_bytes() != source.read_bytes():
        local = existing_root / "custom-local.el"
        if not (local.is_file() and local.read_bytes() == existing.read_bytes()):
            raise ValueError(
                f"Personal settings in {existing} would be replaced. "
                f"Move those settings into {local}, or preserve this path with a local profile rule "
                "before rerunning; no files were changed.")
    if name == "snippets" and exists(existing) and not same_directory_contents(existing, source):
        raise ValueError(
            f"Personal snippets in {existing} differ from the shared directory. "
            "Keep them in a separate local snippet directory and add it to yas-snippet-dirs "
            "in local.el before replacing this path; no files were changed.")


def build_plan(repo, home, profile, skip_emacs=False):
    # Include nonignored new source files so local changes can be reviewed and
    # tested before committing. Runtime Emacs files have an explicit allowlist.
    listing = subprocess.check_output([
        "git", "-C", str(repo), "ls-files", "--cached", "--others",
        "--exclude-standard", "-z", "--", *profile["modules"],
    ]).decode().split("\0")
    emacs_root = home / (".config/emacs" if profile["emacs_target"] == "xdg" else ".emacs.d")
    use_emacs = "emacs" in profile["modules"] and not skip_emacs
    # Materialize directory links and carry a legacy tree into an absent XDG
    # target. Runtime packages and personal files must stay active after moving.
    materialize = emacs_root if use_emacs and emacs_root.is_symlink() else None
    migrations = []
    if use_emacs:
        old_paths = LEGACY_EMACS if profile["emacs_target"] == "xdg" else LEGACY_EMACS[:3]
        for name in old_paths:
            path = home / name
            if exists(path):
                migrations.append(path)
        legacy = home / ".emacs.d"
        if profile["emacs_target"] == "xdg" and exists(legacy):
            if not legacy.is_dir():
                raise ValueError(f"Legacy Emacs state must be a directory: {legacy}")
            if exists(emacs_root):
                if not (emacs_root.is_dir() and emacs_root.samefile(legacy)):
                    raise ValueError(
                        f"Both {legacy} and {emacs_root} contain separate Emacs state. "
                        "Merge or relocate the legacy state explicitly before rerunning; "
                        "neither directory was changed.")
            else:
                materialize = emacs_root
        if materialize is not None:
            check_parents(materialize, home)
            emacs_directory_source(home, materialize)
    existing_emacs_root = emacs_directory_source(home, materialize) if materialize else emacs_root
    entries = []
    seen = set()
    snippet_added = False
    for filename in sorted(set(filter(None, listing))):
        module, separator, relative = filename.partition("/")
        if not separator or module not in profile["modules"]:
            continue
        if module == "emacs":
            if not use_emacs or not relative.startswith(".emacs.d/"):
                continue
            name = relative[len(".emacs.d/"):]
            if name.startswith("snippets/"):
                if snippet_added:
                    continue
                snippet_added = True
                filename = "emacs/.emacs.d/snippets"
                name = "snippets"
            elif name not in EMACS_FILES and not ("/" not in name and name.endswith(".org")):
                continue
            relative = str(emacs_root.relative_to(home) / name)
        relative_path(relative)
        if skip_emacs and (relative.split("/")[0] in LEGACY_EMACS
                           or relative == ".config/emacs" or relative.startswith(".config/emacs/")
                           or relative == ".config/doom" or relative.startswith(".config/doom/")):
            continue
        if matches(relative, profile["exclude"]):
            continue
        if relative in seen:
            raise ValueError(f"Duplicate target: {relative}")
        seen.add(relative)
        source = repo / filename
        if not source.exists() or repo not in source.resolve().parents:
            raise ValueError(f"Missing or external source: {source}")
        target = home / relative
        check_parents(target, home, materialize)
        existing_target = existing_emacs_root / name if module == "emacs" else target
        if target.is_dir() and not target.is_symlink() and not source.is_dir():
            raise ValueError(f"A directory blocks a file target: {target}")
        # The XDG Emacs destination also lives under .config; its explicit
        # package/runtime boundary is independent of desktop copy rules.
        mode = "copy" if module != "emacs" and matches(relative, profile["copy"]) else "link"
        preserve = matches(relative, profile["preserve_existing"]) and exists(existing_target)
        # Detach previously installed desktop links, including machine settings,
        # so future Omarchy updates cannot write through them into this checkout.
        if preserve:
            if mode == "copy" and target.is_symlink() and target.resolve() == source.resolve():
                entries.append({"source": source, "target": target, "relative": relative, "mode": mode})
            continue
        if module == "emacs":
            check_emacs_local_settings(name, source, existing_emacs_root)
        if (mode == "link" and target.is_symlink() and target.resolve() == source.resolve()
                and not (materialize is not None and materialize in target.parents)):
            continue
        if mode == "copy" and target.is_file() and not target.is_symlink():
            if target.read_bytes() == source.read_bytes() and (target.stat().st_mode & 0o777) == (source.stat().st_mode & 0o777):
                continue
        entries.append({"source": source, "target": target, "relative": relative, "mode": mode})
    if use_emacs:
        for name in EMACS_FILES - ({"shell-bashrc"} if profile["emacs_target"] != "xdg" else set()):
            if not (repo / "emacs/.emacs.d" / name).is_file():
                raise ValueError(f"Required Emacs source is missing: {name}")
    return entries, migrations, materialize, emacs_root, use_emacs


def remove(path):
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    elif exists(path):
        path.unlink()


def snapshot(source, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir() and not source.is_symlink():
        shutil.copytree(source, dest, symlinks=True)
    else:
        shutil.copy2(source, dest, follow_symlinks=False)


def copy_emacs_directory(source, target, legacy):
    """Copy local state while keeping relocated links and virtualenvs usable.

    Never follow links while modifying the copy: their external targets can be
    shared repository sources or runtime directories owned by another setup.
    """
    shutil.copytree(source, target, symlinks=True, dirs_exist_ok=True)
    for directory, directories, files in os.walk(source, followlinks=False):
        for name in directories + files:
            original = Path(directory) / name
            if not original.is_symlink():
                continue
            resolved = original.resolve(strict=False)
            if resolved == source or source in resolved.parents:
                resolved = target / resolved.relative_to(source)
            copied = target / original.relative_to(source)
            copied.unlink()
            copied.symlink_to(resolved)

    # Venv launchers are generated text files with absolute paths. Relocate
    # only references into the old Emacs root, never system Python paths or
    # external environments reached through a symlink.
    old_roots = {source, legacy} - {target}
    for directory, _, files in os.walk(target, followlinks=False):
        if "pyvenv.cfg" not in files:
            continue
        venv = Path(directory)
        config, binary_dir = venv / "pyvenv.cfg", venv / "bin"
        if config.is_symlink() or binary_dir.is_symlink() or not binary_dir.is_dir():
            continue
        for path in [config, *binary_dir.iterdir()]:
            if path.is_symlink() or not path.is_file():
                continue
            data = path.read_bytes()
            if b"\0" in data:
                continue
            relocated = data
            for old_root in sorted(old_roots, key=lambda p: len(str(p)), reverse=True):
                relocated = relocated.replace(os.fsencode(str(old_root) + "/"),
                                              os.fsencode(str(target) + "/"))
            if relocated != data:
                path.write_bytes(relocated)
    # These generated files cache absolute package paths. Package.el can
    # rebuild them; the original copies remain untouched in the backup.
    if old_roots:
        for name in ("package-quickstart.el", "package-quickstart.elc"):
            cached = target / name
            if cached.is_file() or cached.is_symlink():
                cached.unlink()


def apply_plan(home, entries, migrations, materialize, profile, state):
    if not entries and not migrations and materialize is None:
        print("All selected configuration files are already applied.")
        return None
    if materialize is not None and exists(materialize) and not materialize.is_symlink():
        raise ValueError(f"Emacs target changed since planning: {materialize}; rerun the installer")
    emacs_source = emacs_directory_source(home, materialize) if materialize is not None else None
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup = home / f".dotfiles-backup-{stamp}"
    backup.mkdir(mode=0o700)
    manifest = {
        "repository": str(REPO), "profile": profile, "completed": False,
        "moved": [str(path.relative_to(home)) for path in migrations],
        "materialized": str(materialize.relative_to(home)) if materialize else None,
        "emacs_state_source": str(emacs_source) if emacs_source else None,
        "files": [{"path": e["relative"], "mode": e["mode"],
                   "source": str(e["source"]), "existed": exists(e["target"]),
                   "source_sha256": hashlib.sha256(e["source"].read_bytes()).hexdigest()
                   if e["source"].is_file() else None} for e in entries],
    }
    manifest_path = backup / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    moved, changed = [], []
    materialized = False
    directory_link_saved = False
    try:
        # Back up first, before changing any installed configuration.
        for entry in entries:
            if exists(entry["target"]):
                snapshot(entry["target"], backup / "originals" / entry["relative"])
        # Materialize before moving legacy paths: the XDG directory link may
        # itself refer to ~/.emacs.d, which is about to be backed up.
        if materialize is not None:
            if materialize.is_symlink():
                materialize.rename(backup / "emacs-directory-link")
                directory_link_saved = True
            materialize.parent.mkdir(parents=True, exist_ok=True)
            # Take ownership of a newly created directory before copying. A
            # target created by another process must never be removed on error.
            materialize.mkdir()
            materialized = True
            copy_emacs_directory(emacs_source, materialize, home / ".emacs.d")
        for path in migrations:
            path.rename(backup / path.name)
            moved.append(path)
        for entry in entries:
            target, source = entry["target"], entry["source"]
            target.parent.mkdir(parents=True, exist_ok=True)
            temporary = target.with_name(target.name + ".dotfiles-new-" + stamp)
            try:
                if entry["mode"] == "copy":
                    shutil.copy2(source, temporary)
                else:
                    temporary.symlink_to(source, target_is_directory=source.is_dir())
                # Include this entry before the first target mutation, so a
                # failed replacement also restores a removed directory.
                changed.append(entry)
                if target.is_dir() and not target.is_symlink():
                    remove(target)
                temporary.replace(target)
            finally:
                remove(temporary)
        manifest["completed"] = True
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    except BaseException:
        for entry in reversed(changed):
            if materialized and materialize in entry["target"].parents:
                # The entire copied tree is removed below, so never restore
                # individual links into it or write through their targets.
                continue
            remove(entry["target"])
            original = backup / "originals" / entry["relative"]
            if exists(original):
                snapshot(original, entry["target"])
        if materialized:
            remove(materialize)
        if directory_link_saved:
            (backup / "emacs-directory-link").rename(materialize)
        for path in reversed(moved):
            remove(path)
            (backup / path.name).rename(path)
        print(f"Configuration apply failed; restored changed paths. Backup: {backup}", file=sys.stderr)
        raise
    state.mkdir(parents=True, exist_ok=True)
    (state / "latest-backup").write_text(str(backup) + "\n")
    print(f"Applied {len(entries)} files. Backup: {backup}")
    return backup


def run(command):
    print("Running:", " ".join(str(part) for part in command), flush=True)
    process = subprocess.Popen([str(part) for part in command], stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True)
    try:
        for line in process.stdout:
            print(line, end="", flush=True)
        code = process.wait()
    except BaseException:
        process.terminate()
        process.wait()
        raise
    if code:
        raise RuntimeError(f"{Path(command[0]).name} failed (exit {code}); rerun the same command after resolving the reported error")


class Tee:
    def __init__(self, stream, logfile):
        self.stream, self.logfile = stream, logfile

    def write(self, text):
        self.stream.write(text)
        self.logfile.write(text)
        self.logfile.flush()

    def flush(self):
        self.stream.flush()
        self.logfile.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=("auto", "omarchy", "linux", "macos"), default="auto")
    parser.add_argument("--dry-run", action="store_true", help="preview; do not write files or install packages")
    parser.add_argument("--config-only", action="store_true", help="apply config without installing system or Emacs packages")
    parser.add_argument("--skip-emacs", action="store_true", help="leave all Emacs paths and packages untouched")
    parser.add_argument("--reload", action="store_true", help="reload a running Emacs daemon after successful setup")
    parser.add_argument("--local", type=Path, help="machine overrides (default: ~/.config/dotfiles/local.json)")
    args = parser.parse_args()
    os.umask(0o077)
    home = Path.home().resolve()
    config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
    state = Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")) / "dotfiles"
    name = args.profile
    if name == "auto":
        name = "macos" if sys.platform == "darwin" else "omarchy" if shutil.which("omarchy") else "linux"
    if name == "omarchy" and config != home / ".config":
        raise ValueError("Omarchy's managed configuration requires XDG_CONFIG_HOME=$HOME/.config")
    local = args.local.expanduser() if args.local else config / "dotfiles/local.json"
    profile = load_profile(REPO, name, local)
    entries, migrations, materialize, emacs_root, use_emacs = build_plan(REPO, home, profile, args.skip_emacs)
    if not args.dry_run:
        state.mkdir(parents=True, exist_ok=True)
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        logpath = state / f"install-{stamp}.log"
        logfile = logpath.open("w")
        sys.stdout = Tee(sys.stdout, logfile)
        sys.stderr = Tee(sys.stderr, logfile)
        print(f"Install log: {logpath}")
    print(f"Repository: {REPO}\nProfile: {name}; overrides: {local if local.is_file() else 'none'}")
    for path in migrations:
        print(f"  backup legacy Emacs path: {path}")
    if materialize:
        source = emacs_directory_source(home, materialize)
        print(f"  retain Emacs packages and local state: {source} -> {materialize}")
    for entry in entries:
        print(f"  {entry['mode']}: {entry['relative']}")
    print(f"Configuration changes: {len(entries)}; Emacs: {'included' if use_emacs else 'excluded'}")
    if not args.config_only:
        command = [REPO / "scripts/setup-system.sh", "--profile", name]
        if not use_emacs:
            command.append("--skip-emacs")
        if args.dry_run:
            command.append("--dry-run")
        run(command)
    if args.dry_run:
        if use_emacs and not args.config_only:
            print(f"Then install missing Emacs packages and validate: {emacs_root}")
        print("Dry run complete; no files or packages changed.")
        return
    apply_plan(home, entries, migrations, materialize, profile, state)
    if use_emacs and not args.config_only:
        command = [REPO / "scripts/setup-emacs.sh", "--config-dir", emacs_root]
        if args.reload:
            command.append("--reload")
        run(command)
    print("Configuration applied." if args.config_only else "Dotfiles setup completed.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Setup stopped: {error}", file=sys.stderr)
        sys.exit(1)
