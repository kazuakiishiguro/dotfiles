"""Verify shared Git defaults and per-machine overrides in a temporary home."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPOSITORY = Path(__file__).resolve().parents[2]


class GitConfigTests(unittest.TestCase):
    def test_machine_config_overrides_shared_defaults(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary).resolve()
            shutil.copyfile(REPOSITORY / "git/.gitconfig", home / ".gitconfig")
            environment = dict(os.environ, HOME=str(home), GIT_CONFIG_NOSYSTEM="1",
                               GIT_CONFIG_GLOBAL=str(home / ".gitconfig"))

            def program():
                return subprocess.check_output(
                    ["git", "config", "--get", "gpg.program"],
                    cwd=home, env=environment, text=True).strip()

            self.assertEqual(program(), "gpg-for-git")
            local = home / ".config/git/config"
            local.parent.mkdir(parents=True)
            local.write_text("[gpg]\n\tprogram = /opt/homebrew/bin/gpg\n")
            self.assertEqual(program(), "/opt/homebrew/bin/gpg")


if __name__ == "__main__":
    unittest.main()
