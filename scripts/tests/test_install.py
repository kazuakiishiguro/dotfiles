"""Verify installer safety using fixture repositories and temporary homes."""

from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


INSTALL_SCRIPT = Path(__file__).resolve().parents[1] / "install.py"
SPEC = importlib.util.spec_from_file_location("dotfiles_install", INSTALL_SCRIPT)
INSTALLER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(INSTALLER)


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "fixture repository"
        self.home = self.root / "home"
        self.repo.mkdir()
        self.home.mkdir()
        self.state = self.home / ".local/state/dotfiles"
        self.git_env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True, env=self.git_env)
        self.source("shell/.shellrc", "shared shell\n")
        self.source("config/.config/hypr/input.lua", "shared input\n")
        self.source("config/.config/hypr/monitors.lua", "shared monitor\n")
        self.source("config/.config/fcitx5/config", "shared IME\n")
        for name in INSTALLER.EMACS_FILES:
            self.source("emacs/.emacs.d/" + name, "; shared " + name + "\n")
        self.source("emacs/.emacs.d/configuration.org", "* Shared literate configuration\n")
        self.source("emacs/.emacs.d/snippets/python-mode/fixture", "shared snippet\n")
        self.track_sources()

    def source(self, relative, content):
        path = self.repo / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def installed_file(self, relative, content):
        path = self.home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def track_sources(self):
        subprocess.run(["git", "-C", str(self.repo), "add", "--all"], check=True, env=self.git_env)

    def profile(self, **overrides):
        result = {
            "modules": ["shell", "config", "emacs"],
            "emacs_target": "xdg", "exclude": [],
            "preserve_existing": [".config/hypr/monitors.lua", ".config/fcitx5/config"],
            "copy": [".config/**"],
        }
        result.update(overrides)
        return result

    def plan(self, profile=None, skip_emacs=False):
        return INSTALLER.build_plan(self.repo, self.home, profile or self.profile(), skip_emacs)

    def apply(self, plan, profile=None):
        entries, migrations, materialize, _, _ = plan
        with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            return INSTALLER.apply_plan(self.home, entries, migrations, materialize,
                                        profile or self.profile(), self.state)

    def test_fresh_install_then_rerun_creates_no_extra_backup(self):
        profile = self.profile()
        first = self.apply(self.plan(profile), profile)
        self.assertTrue((self.home / ".shellrc").is_symlink())
        self.assertFalse((self.home / ".config/hypr/input.lua").is_symlink())
        self.assertTrue((self.home / ".config/emacs/init.el").is_symlink())
        self.assertTrue((self.home / ".config/emacs/snippets").is_symlink())
        self.assertTrue(json.loads((first / "manifest.json").read_text())["completed"])
        second_plan = self.plan(profile)
        self.assertEqual(second_plan[0:3], ([], [], None))
        self.assertIsNone(self.apply(second_plan, profile))
        self.assertEqual(list(self.home.glob(".dotfiles-backup-*")), [first])
        self.assertEqual((self.state / "latest-backup").read_text().strip(), str(first))

    def test_desktop_copy_isolates_repository_from_external_updates(self):
        self.apply(self.plan())
        target = self.home / ".config/hypr/input.lua"
        target.write_text("Omarchy update changed the installed configuration\n")
        self.assertEqual((self.repo / "config/.config/hypr/input.lua").read_text(), "shared input\n")

    def test_preserve_existing_retains_machine_monitor_and_ime(self):
        monitor = self.installed_file(".config/hypr/monitors.lua", "machine monitor\n")
        ime = self.installed_file(".config/fcitx5/config", "machine IME\n")
        plan = self.plan()
        targets = {entry["target"] for entry in plan[0]}
        self.assertNotIn(monitor, targets)
        self.assertNotIn(ime, targets)
        self.apply(plan)
        self.assertEqual(monitor.read_text(), "machine monitor\n")
        self.assertEqual(ime.read_text(), "machine IME\n")

    def test_preserved_old_repository_link_is_detached_into_a_copy(self):
        source = self.repo / "config/.config/hypr/monitors.lua"
        target = self.home / ".config/hypr/monitors.lua"
        target.parent.mkdir(parents=True)
        target.symlink_to(source)
        self.apply(self.plan())
        self.assertFalse(target.is_symlink())
        target.write_text("host-specific change\n")
        self.assertEqual(source.read_text(), "shared monitor\n")

    def test_skip_emacs_retains_every_startup_path_and_legacy_directory(self):
        old_init = self.installed_file(".emacs", "old startup\n")
        old_cache = self.installed_file(".emacs.d/elpa/runtime", "cached packages\n")
        plan = self.plan(skip_emacs=True)
        self.assertFalse(plan[-1])
        self.assertEqual(plan[1], [])
        self.assertFalse(any("emacs" in entry["relative"] for entry in plan[0]))
        self.apply(plan)
        self.assertEqual(old_init.read_text(), "old startup\n")
        self.assertEqual(old_cache.read_text(), "cached packages\n")
        self.assertFalse((self.home / ".config/emacs").exists())

    def test_skip_emacs_also_excludes_emacs_paths_inside_other_modules(self):
        self.source("config/.config/emacs/init.el", "another module's Emacs config\n")
        self.source("config/.emacs", "another module's legacy init\n")
        self.track_sources()
        plan = self.plan(skip_emacs=True)
        self.apply(plan)
        self.assertFalse((self.home / ".emacs").exists())
        self.assertFalse((self.home / ".config/emacs").exists())

    def test_xdg_migration_keeps_legacy_runtime_and_local_settings_active(self):
        self.installed_file(".emacs", "legacy startup\n")
        self.installed_file(".emacs.el", "legacy alternate startup\n")
        self.installed_file(".emacs.elc", "legacy compiled startup\n")
        self.installed_file(".emacs.d/elpa/runtime", "legacy cached package\n")
        self.installed_file(".emacs.d/local.el", "; host settings\n")
        self.installed_file(".emacs.d/custom-local.el", "; local preferences\n")
        self.installed_file(".emacs.d/bookmarks", "personal bookmarks\n")
        self.installed_file(".emacs.d/eshell/history", "shell history\n")
        backup = self.apply(self.plan())
        for name in INSTALLER.LEGACY_EMACS:
            self.assertFalse((self.home / name).exists())
        self.assertEqual((backup / ".emacs").read_text(), "legacy startup\n")
        for relative in ("elpa/runtime", "local.el", "custom-local.el", "bookmarks", "eshell/history"):
            self.assertEqual((self.home / ".config/emacs" / relative).read_bytes(),
                             (backup / ".emacs.d" / relative).read_bytes())
        self.assertTrue((self.home / ".config/emacs/init.el").is_symlink())
        self.assertEqual(self.plan()[0:3], ([], [], None))

    def test_distinct_legacy_and_xdg_state_are_rejected_before_mutation(self):
        legacy = self.installed_file(".emacs.d/local.el", "legacy settings\n")
        current = self.installed_file(".config/emacs/local.el", "current settings\n")
        with self.assertRaisesRegex(ValueError, "separate Emacs state"):
            self.plan()
        self.assertEqual(legacy.read_text(), "legacy settings\n")
        self.assertEqual(current.read_text(), "current settings\n")
        self.assertEqual(list(self.home.glob(".dotfiles-backup-*")), [])

    def test_personal_customize_settings_require_preservation_before_replacement(self):
        personal = self.installed_file(".emacs.d/custom.el", "; personal preferences\n")
        with self.assertRaisesRegex(ValueError, "custom-local.el"):
            self.plan()
        self.assertEqual(personal.read_text(), "; personal preferences\n")
        self.assertEqual(list(self.home.glob(".dotfiles-backup-*")), [])
        self.installed_file(".emacs.d/custom-local.el", personal.read_text())
        self.apply(self.plan())
        self.assertEqual((self.home / ".config/emacs/custom-local.el").read_text(),
                         "; personal preferences\n")
        self.assertEqual((self.home / ".config/emacs/custom.el").resolve(),
                         self.repo / "emacs/.emacs.d/custom.el")

    def test_personal_snippets_require_explicit_preservation_before_replacement(self):
        snippet = self.installed_file(".emacs.d/snippets/custom-mode/user", "personal snippet\n")
        with self.assertRaisesRegex(ValueError, "Personal snippets"):
            self.plan()
        self.assertEqual(snippet.read_text(), "personal snippet\n")
        self.assertEqual(list(self.home.glob(".dotfiles-backup-*")), [])

    def test_preserve_rules_apply_to_files_carried_from_legacy_emacs(self):
        self.installed_file(".emacs.d/custom.el", "; personal preferences\n")
        self.installed_file(".emacs.d/snippets/local-mode/user", "personal snippet\n")
        profile = self.profile(preserve_existing=[".config/emacs/custom.el", ".config/emacs/snippets"])
        self.apply(self.plan(profile), profile)
        self.assertEqual((self.home / ".config/emacs/custom.el").read_text(), "; personal preferences\n")
        self.assertEqual((self.home / ".config/emacs/snippets/local-mode/user").read_text(), "personal snippet\n")

    def test_legacy_alias_of_active_xdg_directory_is_backed_up_without_copying(self):
        cache = self.installed_file(".config/emacs/elpa/current", "active package\n")
        legacy = self.home / ".emacs.d"
        legacy.symlink_to(".config/emacs", target_is_directory=True)
        plan = self.plan()
        self.assertIsNone(plan[2])
        backup = self.apply(plan)
        self.assertFalse(legacy.is_symlink())
        self.assertEqual(cache.read_text(), "active package\n")
        self.assertTrue((backup / ".emacs.d").is_symlink())

    def test_legacy_directory_link_becomes_real_directory_retaining_runtime(self):
        old_directory = self.root / "old Emacs state"
        (old_directory / "elpa").mkdir(parents=True)
        (old_directory / "elpa/runtime").write_text("keep installed package\n")
        (old_directory / "init.el").write_text("old init\n")
        emacs_root = self.home / ".emacs.d"
        emacs_root.symlink_to(old_directory, target_is_directory=True)
        profile = self.profile(modules=["emacs"], emacs_target="legacy", copy=[])
        backup = self.apply(self.plan(profile), profile)
        self.assertFalse(emacs_root.is_symlink())
        self.assertTrue((emacs_root / "init.el").is_symlink())
        self.assertEqual((emacs_root / "elpa/runtime").read_text(), "keep installed package\n")
        self.assertEqual((old_directory / "init.el").read_text(), "old init\n")
        self.assertTrue((backup / "emacs-directory-link").is_symlink())
        self.assertEqual(self.plan(profile)[0:3], ([], [], None))

    def test_xdg_link_to_legacy_directory_retains_runtime_before_migration(self):
        old = self.installed_file(".emacs.d/elpa/runtime", "keep legacy runtime\n").parents[1]
        xdg = self.home / ".config/emacs"
        xdg.parent.mkdir()
        xdg.symlink_to(old, target_is_directory=True)
        backup = self.apply(self.plan())
        self.assertFalse(xdg.is_symlink())
        self.assertFalse((self.home / ".emacs.d").exists())
        self.assertEqual((xdg / "elpa/runtime").read_text(), "keep legacy runtime\n")
        self.assertEqual((backup / ".emacs.d/elpa/runtime").read_text(), "keep legacy runtime\n")

    def test_xdg_migration_rebases_stow_and_internal_runtime_links(self):
        old = self.installed_file(".emacs.d/elpa/runtime", "runtime bytes\n").parents[1]
        source = self.repo / "emacs/.emacs.d/init.el"
        (old / "init.el").symlink_to(os.path.relpath(source, old))
        (old / "runtime-alias").symlink_to("elpa/runtime")
        (old / "absolute-alias").symlink_to(old / "elpa/runtime")
        external = self.root / "external personal state"
        external.write_text("external data\n")
        (old / "external-alias").symlink_to(os.path.relpath(external, old))
        target = self.home / ".config/emacs"
        target.parent.mkdir()
        target.symlink_to("../.emacs.d", target_is_directory=True)
        plan = self.plan()
        self.assertIn(target / "init.el", {entry["target"] for entry in plan[0]})
        backup = self.apply(plan)
        self.assertEqual((target / "init.el").resolve(), source)
        self.assertEqual((target / "runtime-alias").resolve(), target / "elpa/runtime")
        self.assertEqual((target / "absolute-alias").resolve(), target / "elpa/runtime")
        self.assertEqual((target / "runtime-alias").read_text(), "runtime bytes\n")
        self.assertEqual((target / "external-alias").resolve(), external)
        self.assertEqual(external.read_text(), "external data\n")
        self.assertEqual(os.readlink(backup / ".emacs.d/init.el"), os.path.relpath(source, old))

    def test_migration_relocates_venv_launchers_without_touching_external_files(self):
        old = self.home / ".emacs.d"
        target = self.home / ".config/emacs"
        old_venv = old / "elpy/rpc-venv"
        self.installed_file(".emacs.d/elpy/rpc-venv/pyvenv.cfg",
                            f"home = /usr/bin\ncommand = python -m venv {old_venv}\n")
        launcher = self.installed_file(".emacs.d/elpy/rpc-venv/bin/pip",
                                       f"#!{old_venv}/bin/python\n")
        launcher.chmod(0o755)
        self.installed_file(".emacs.d/elpy/rpc-venv/bin/activate",
                            f'VIRTUAL_ENV="{old_venv}"\nOTHER="{old}ifferent/keep"\n')
        external = self.root / "external-launcher"
        external.write_text(f"#!{old_venv}/bin/python\n")
        (old_venv / "bin/external").symlink_to(external)
        self.installed_file(".emacs.d/package-quickstart.el", f"cached {old}/elpa\n")
        backup = self.apply(self.plan())
        new_venv = target / "elpy/rpc-venv"
        self.assertEqual((new_venv / "bin/pip").read_text(), f"#!{new_venv}/bin/python\n")
        self.assertEqual((new_venv / "bin/pip").stat().st_mode & 0o777, 0o755)
        self.assertIn("home = /usr/bin", (new_venv / "pyvenv.cfg").read_text())
        self.assertIn(f'{old}ifferent/keep', (new_venv / "bin/activate").read_text())
        self.assertEqual(external.read_text(), f"#!{old_venv}/bin/python\n")
        self.assertFalse((target / "package-quickstart.el").exists())
        self.assertTrue((backup / ".emacs.d/package-quickstart.el").exists())
        self.assertEqual((backup / ".emacs.d/elpy/rpc-venv/bin/pip").read_text(),
                         f"#!{old_venv}/bin/python\n")

    def test_emacs_link_to_parent_of_target_is_rejected_before_copying(self):
        (self.home / ".emacs.d").symlink_to(self.home, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "parent of its target"):
            self.plan()
        self.assertEqual(list(self.home.glob(".dotfiles-backup-*")), [])

    def test_failed_apply_restores_legacy_tree_and_original_relative_links(self):
        old = self.installed_file(".emacs.d/bookmarks", "original bookmarks\n").parent
        source = self.repo / "emacs/.emacs.d/init.el"
        (old / "init.el").symlink_to(os.path.relpath(source, old))
        target = self.home / ".config/emacs"
        original_replace = Path.replace

        def failing_replace(path, destination):
            if Path(destination) == target / "init.el":
                raise OSError("injected migration failure")
            return original_replace(path, destination)

        plan = self.plan()
        with mock.patch.object(Path, "replace", failing_replace):
            with self.assertRaisesRegex(OSError, "injected migration failure"):
                self.apply(plan)
        self.assertFalse(target.exists())
        self.assertEqual((old / "bookmarks").read_text(), "original bookmarks\n")
        self.assertEqual((old / "init.el").resolve(), source)
        self.assertEqual(os.readlink(old / "init.el"), os.path.relpath(source, old))

    def test_failed_materialization_restores_outer_link_and_original_tree(self):
        old = self.installed_file(".emacs.d/bookmarks", "original bookmarks\n").parent
        target = self.home / ".config/emacs"
        target.parent.mkdir()
        target.symlink_to("../.emacs.d", target_is_directory=True)
        original_copytree = INSTALLER.shutil.copytree

        def failing_copytree(source, destination, *args, **kwargs):
            if Path(destination) == target:
                (target / "partial").write_text("partial copy\n")
                raise OSError("injected copy failure")
            return original_copytree(source, destination, *args, **kwargs)

        plan = self.plan()
        with mock.patch.object(INSTALLER.shutil, "copytree", failing_copytree):
            with self.assertRaisesRegex(OSError, "injected copy failure"):
                self.apply(plan)
        self.assertTrue(target.is_symlink())
        self.assertEqual(os.readlink(target), "../.emacs.d")
        self.assertEqual((target / "bookmarks").read_text(), "original bookmarks\n")
        self.assertEqual((old / "bookmarks").read_text(), "original bookmarks\n")

    def test_migration_refuses_target_created_after_planning(self):
        old = self.installed_file(".emacs.d/bookmarks", "old bookmarks\n")
        plan = self.plan()
        new = self.installed_file(".config/emacs/local.el", "newly created settings\n")
        with self.assertRaisesRegex(ValueError, "changed since planning"):
            self.apply(plan)
        self.assertEqual(old.read_text(), "old bookmarks\n")
        self.assertEqual(new.read_text(), "newly created settings\n")
        self.assertEqual(list(self.home.glob(".dotfiles-backup-*")), [])

    def test_symlink_parent_is_rejected_before_any_changes(self):
        outside = self.root / "external config"
        outside.mkdir()
        (self.home / ".config").symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "real directory"):
            self.plan()
        self.assertEqual(list(outside.iterdir()), [])
        self.assertEqual(list(self.home.glob(".dotfiles-backup-*")), [])

    def test_local_overrides_extend_patterns_and_replace_module_selection(self):
        profile = self.profile()
        self.source("profiles/omarchy.json", json.dumps(profile))
        local = self.root / "local.json"
        local.write_text(json.dumps({"modules": ["shell"], "exclude": [".shellrc"],
                                     "preserve_existing": [".other"], "copy": [".another"]}))
        loaded = INSTALLER.load_profile(self.repo, "omarchy", local)
        self.assertEqual(loaded["modules"], ["shell"])
        self.assertEqual(loaded["preserve_existing"], profile["preserve_existing"] + [".other"])
        self.assertEqual(loaded["copy"], profile["copy"] + [".another"])
        self.assertEqual(self.plan(loaded)[0], [])

    def test_invalid_local_keys_and_module_traversal_are_rejected(self):
        self.source("profiles/omarchy.json", json.dumps(self.profile()))
        local = self.root / "local.json"
        for data in ({"repository": "/elsewhere"}, {"modules": ["../elsewhere"]}, {"copy": "*"}):
            with self.subTest(data=data):
                local.write_text(json.dumps(data))
                with self.assertRaises(ValueError):
                    INSTALLER.load_profile(self.repo, "omarchy", local)

    def test_failed_mutation_restores_overwritten_files_and_removes_temporaries(self):
        self.installed_file(".shellrc", "original shell\n")
        self.installed_file(".config/hypr/input.lua", "original input\n")
        profile = self.profile(modules=["shell", "config"], preserve_existing=[])
        plan = self.plan(profile)
        fail_target = plan[0][1]["target"]
        original_replace = Path.replace

        def failing_replace(path, target):
            if Path(target) == fail_target:
                raise OSError("injected disk failure")
            return original_replace(path, target)

        with mock.patch.object(Path, "replace", failing_replace):
            with self.assertRaisesRegex(OSError, "injected disk failure"):
                self.apply(plan, profile)
        self.assertEqual((self.home / ".shellrc").read_text(), "original shell\n")
        self.assertEqual((self.home / ".config/hypr/input.lua").read_text(), "original input\n")
        self.assertEqual(list(self.home.rglob("*.dotfiles-new-*")), [])
        self.assertFalse((self.state / "latest-backup").exists())
        backup = next(self.home.glob(".dotfiles-backup-*"))
        self.assertFalse(json.loads((backup / "manifest.json").read_text())["completed"])

    def test_failed_directory_replacement_restores_existing_snippet_tree(self):
        snippet = self.installed_file(".config/emacs/snippets/python-mode/fixture", "shared snippet\n")
        plan = self.plan()
        snippet_target = self.home / ".config/emacs/snippets"
        original_replace = Path.replace

        def failing_replace(path, target):
            if Path(target) == snippet_target:
                raise OSError("injected snippet replacement failure")
            return original_replace(path, target)

        with mock.patch.object(Path, "replace", failing_replace):
            with self.assertRaisesRegex(OSError, "snippet replacement failure"):
                self.apply(plan)
        self.assertEqual(snippet.read_text(), "shared snippet\n")
        self.assertFalse(snippet_target.is_symlink())

    def test_runtime_and_documentation_files_are_not_applied_as_emacs_sources(self):
        self.source("emacs/.emacs.d/elpa/runtime.el", "; runtime package\n")
        self.source("emacs/.emacs.d/CLAUDE.md", "developer documentation\n")
        self.source("emacs/.emacs.d/configuration.el", "; generated tangle\n")
        self.track_sources()
        plan = self.plan()
        targets = {entry["relative"] for entry in plan[0]}
        self.assertNotIn(".config/emacs/elpa/runtime.el", targets)
        self.assertNotIn(".config/emacs/CLAUDE.md", targets)
        self.assertNotIn(".config/emacs/configuration.el", targets)

    def test_real_cli_dry_run_writes_neither_logs_nor_config(self):
        environment = dict(os.environ, HOME=str(self.home),
                           XDG_CONFIG_HOME=str(self.home / ".config"),
                           XDG_STATE_HOME=str(self.home / ".local/state"))
        result = subprocess.run([sys.executable, str(INSTALL_SCRIPT), "--profile", "omarchy",
                                 "--config-only", "--skip-emacs", "--dry-run"],
                                env=environment, cwd=self.root, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no files or packages changed", result.stdout)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_real_cli_dry_run_does_not_move_legacy_runtime(self):
        bookmark = self.installed_file(".emacs.d/bookmarks", "personal bookmarks\n")
        environment = dict(os.environ, HOME=str(self.home),
                           XDG_CONFIG_HOME=str(self.home / ".config"),
                           XDG_STATE_HOME=str(self.home / ".local/state"))
        result = subprocess.run([sys.executable, str(INSTALL_SCRIPT), "--profile", "omarchy",
                                 "--config-only", "--dry-run"], env=environment,
                                cwd=self.root, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("retain Emacs packages and local state", result.stdout)
        self.assertEqual(bookmark.read_text(), "personal bookmarks\n")
        self.assertEqual(list(self.home.iterdir()), [self.home / ".emacs.d"])

    def test_full_orchestration_provisions_before_apply_then_installs_emacs(self):
        self.source("profiles/omarchy.json", json.dumps(self.profile()))
        commands = []

        def record(command):
            commands.append([str(part) for part in command])
            if len(commands) == 1:
                self.assertFalse((self.home / ".shellrc").exists())
            else:
                self.assertTrue((self.home / ".config/emacs/init.el").is_symlink())

        environment = {"HOME": str(self.home), "XDG_CONFIG_HOME": str(self.home / ".config"),
                       "XDG_STATE_HOME": str(self.home / ".local/state")}
        with mock.patch.dict(os.environ, environment), mock.patch.object(INSTALLER, "REPO", self.repo), \
                mock.patch.object(INSTALLER, "run", side_effect=record), \
                mock.patch.object(sys, "argv", ["install.py", "--profile", "omarchy"]), \
                redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            INSTALLER.main()
            sys.stdout.flush()
            sys.stdout.logfile.close()
        self.assertEqual(Path(commands[0][0]).name, "setup-system.sh")
        self.assertEqual(Path(commands[1][0]).name, "setup-emacs.sh")
        self.assertEqual(commands[1][-1], str(self.home / ".config/emacs"))

    def test_compatibility_helper_remains_preview_first_when_symlinked(self):
        helper = self.root / "helper with spaces"
        helper.symlink_to(INSTALL_SCRIPT.parent / "apply-config.sh")
        environment = dict(os.environ, HOME=str(self.home),
                           XDG_CONFIG_HOME=str(self.home / ".config"),
                           XDG_STATE_HOME=str(self.home / ".local/state"))
        result = subprocess.run(["bash", str(helper), "--profile", "omarchy"],
                                env=environment, cwd=self.root, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no files or packages changed", result.stdout)
        self.assertEqual(list(self.home.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
