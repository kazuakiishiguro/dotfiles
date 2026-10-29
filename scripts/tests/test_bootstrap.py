"""Bootstrap tests use local Git repositories; no network or package installs.

Set DOTFILES_TEST_BASH to an older Bash binary to exercise its actual semantics.
"""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPOSITORY = Path(__file__).resolve().parents[2]
BOOTSTRAP = REPOSITORY / "bootstrap.sh"
ORIGIN = "https://github.com/kazuakiishiguro/dotfiles.git"
BASH = os.environ.get("DOTFILES_TEST_BASH", "bash")


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.output = self.root / "init-arguments.json"
        self.env = dict(os.environ, HOME=str(self.home), INIT_OUTPUT=str(self.output))
        self.env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)

    def make_checkout(self, directory=None, origin=ORIGIN):
        directory = directory or self.home / "fun" / "dotfiles"
        directory.mkdir(parents=True)
        subprocess.run(["git", "init", "-q", str(directory)], check=True, env=self.env)
        subprocess.run(["git", "-C", str(directory), "remote", "add", "origin", origin], check=True, env=self.env)
        (directory / "init.sh").write_text(
            "#!/usr/bin/env bash\n"
            "python3 -c 'import json, os, sys; open(os.environ[\"INIT_OUTPUT\"], \"w\").write(json.dumps(sys.argv[1:]))' \"$@\"\n"
        )
        return directory

    def run_bootstrap(self, *arguments):
        return subprocess.run(
            [BASH, str(BOOTSTRAP), *map(str, arguments)],
            cwd=self.root, env=self.env, capture_output=True, text=True,
        )

    def test_reuses_default_checkout_and_forwards_flags(self):
        directory = self.make_checkout()
        (directory / "uncommitted-work").write_text("keep me")
        result = self.run_bootstrap("--profile", "omarchy", "--skip-emacs")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text()), ["--profile", "omarchy", "--skip-emacs"])
        self.assertEqual((directory / "uncommitted-work").read_text(), "keep me")
        self.assertIn("without pulling or resetting", result.stdout)

    def test_reuses_checkout_without_installer_arguments(self):
        directory = self.make_checkout()
        for arguments in ((), ("--dir", directory), ("--",)):
            with self.subTest(arguments=arguments):
                result = self.run_bootstrap(*arguments)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(self.output.read_text()), [])

    def test_preserves_an_explicit_empty_argument(self):
        self.make_checkout()
        result = self.run_bootstrap("--local", "", "--skip-emacs")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text()), ["--local", "", "--skip-emacs"])

    def test_directory_with_spaces_and_literal_shell_characters(self):
        directory = self.make_checkout(self.root / "repo with spaces $(never-run)")
        result = self.run_bootstrap("--dir", directory, "--profile", "omarchy", "--local", "a file.json")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text()), ["--profile", "omarchy", "--local", "a file.json"])

    def test_rejects_different_origin_without_running_init(self):
        directory = self.make_checkout(origin="https://github.com/other/dotfiles.git")
        result = self.run_bootstrap("--dir", directory)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("different origin", result.stderr)
        self.assertFalse(self.output.exists())

    def test_rejects_subdirectory_of_checkout(self):
        directory = self.make_checkout()
        child = directory / "child"
        child.mkdir()
        result = self.run_bootstrap("--dir", child)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("repository root", result.stderr)
        self.assertFalse(self.output.exists())

    def test_dry_run_new_checkout_does_not_create_directories(self):
        directory = self.home / "fun" / "dotfiles"
        result = self.run_bootstrap("--dry-run", "--profile", "omarchy")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("git clone", result.stdout)
        self.assertIn("--dry-run", result.stdout)
        self.assertFalse(directory.exists())

    def test_existing_dry_run_forwards_to_init(self):
        self.make_checkout()
        result = self.run_bootstrap("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text()), ["--dry-run"])

    def test_dry_run_after_separator_still_prevents_clone(self):
        result = self.run_bootstrap("--", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / "fun" / "dotfiles").exists())

    def test_fresh_clone_runs_init_without_network(self):
        source = self.make_checkout(self.root / "local upstream")
        subprocess.run(["git", "-C", str(source), "add", "init.sh"], check=True, env=self.env)
        subprocess.run(["git", "-C", str(source), "-c", "user.name=Fixture", "-c",
                        "user.email=fixture@example.invalid", "commit", "-qm", "fixture"],
                       check=True, env=self.env)
        self.env.update(GIT_CONFIG_COUNT="1", GIT_CONFIG_KEY_0=f"url.{source.as_uri()}.insteadOf",
                        GIT_CONFIG_VALUE_0=ORIGIN)
        destination = self.root / "fresh checkout"
        result = self.run_bootstrap("--dir", destination)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((destination / ".git").is_dir())
        self.assertEqual(json.loads(self.output.read_text()), [])

    def test_non_repository_is_retained(self):
        directory = self.home / "fun" / "dotfiles"
        directory.mkdir(parents=True)
        original = directory / "keep"
        original.write_text("original")
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(original.read_text(), "original")

    def test_missing_directory_argument_is_usage_error(self):
        result = self.run_bootstrap("--dir")
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
