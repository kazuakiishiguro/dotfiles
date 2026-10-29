"""Entry-point environment checks use disposable homes and fake tool locations.

DOTFILES_TEST_BASH can select the actual macOS Bash 3.2 executable.
"""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


REPOSITORY = Path(__file__).resolve().parents[2]
BASH = shutil.which(os.environ.get("DOTFILES_TEST_BASH", "bash"))


class InitEnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="dotfiles-init-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.home = self.root / "home"
        self.home.mkdir()
        self.checkout = self.root / "checkout with spaces"
        (self.checkout / "scripts").mkdir(parents=True)
        self.system = self.root / "usr/bin"
        self.system.mkdir(parents=True)
        self.arm = self.root / "opt/homebrew"
        self.intel = self.root / "usr/local"
        self.tex = self.root / "texbin"
        self.output = self.root / "result.json"
        self.calls = self.root / "calls"
        self.calls.write_text("")
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.system),
                        MOCK_OUTPUT=str(self.output), MOCK_CALLS=str(self.calls),
                        MOCK_PLATFORM="Darwin", MOCK_CLT="1")
        for variable in ("BASH_ENV", "EMACS", "EMACSCLIENT", "XDG_CONFIG_HOME", "XDG_STATE_HOME"):
            self.env.pop(variable, None)
        for tool in ("dirname", "mkdir", "date", "tee"):
            (self.system / tool).symlink_to(shutil.which(tool))
        (self.system / "bash").symlink_to(BASH)
        self.command(self.system / "uname", 'printf "%s\\n" "$MOCK_PLATFORM"\n')
        self.command(self.system / "xcode-select",
                     '[ "$MOCK_CLT" = 1 ] || exit 1\nprintf "%s\\n" "$HOME"\n')
        self.python(self.system / "python3")
        self.command(self.system / "git", 'printf "git-stub\\n" >> "$MOCK_CALLS"\nexit 9\n')
        for relative in ("init.sh", "scripts/macos-env.sh", "scripts/setup-emacs.sh"):
            source = (REPOSITORY / relative).read_text()
            for original, fixture in (("/opt/homebrew", self.arm), ("/usr/local", self.intel),
                                      ("/Library/TeX/texbin", self.tex),
                                      ("/usr/bin/python3", self.system / "python3"),
                                      ("/usr/bin/git", self.system / "git")):
                source = source.replace(original, str(fixture))
            (self.checkout / relative).write_text(source)
        (self.checkout / "scripts/install.py").write_text('''
import json, os, shutil, subprocess, sys
probe = "import json, shutil; print(json.dumps({name: shutil.which(name) for name in ('emacs', 'cargo', 'pdflatex', 'python3')}))"
phases = [json.loads(subprocess.check_output([sys.executable, '-c', probe], text=True))
          for phase in ('system', 'emacs')]
with open(os.environ['MOCK_OUTPUT'], 'w') as output:
    json.dump({'phases': phases, 'arguments': sys.argv[1:]}, output)
''')

    def command(self, path, body):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(0o755)

    def python(self, path):
        self.command(path, 'printf "python\\n" >> "$MOCK_CALLS"\n'
                     f'exec {shlex.quote(sys.executable)} "$@"\n')

    def homebrew(self, prefix):
        # Any package-manager invocation would be a test failure.
        self.command(prefix / "bin/brew", "exit 99\n")
        (prefix / "sbin").mkdir()
        self.command(prefix / "bin/emacs", "exit 0\n")

    def run_init(self, *arguments):
        return subprocess.run([BASH, str(self.checkout / "init.sh"), *arguments],
                              env=self.env, cwd=self.root, text=True, capture_output=True)

    def test_macos_paths_reach_installer_and_both_child_phases(self):
        for prefix in (self.arm, self.intel):
            with self.subTest(prefix=prefix.name):
                self.homebrew(prefix)
                self.command(self.home / ".cargo/bin/cargo", "exit 0\n")
                self.command(self.tex / "pdflatex", "exit 0\n")
                result = self.run_init("--dry-run", "--profile", "macos")
                self.assertEqual(result.returncode, 0, result.stderr)
                report = json.loads(self.output.read_text())
                self.assertEqual(report["arguments"], ["--dry-run", "--profile", "macos"])
                for phase in report["phases"]:
                    self.assertEqual(phase["emacs"], str(prefix / "bin/emacs"))
                    self.assertEqual(phase["cargo"], str(self.home / ".cargo/bin/cargo"))
                    self.assertEqual(phase["pdflatex"], str(self.tex / "pdflatex"))
                shutil.rmtree(prefix)

    def test_selected_tools_stay_ahead_of_discovered_homebrew(self):
        self.homebrew(self.arm)
        selected = self.root / "selected"
        for name in ("emacs", "cargo", "pdflatex"):
            self.command(selected / name, "exit 0\n")
        self.python(selected / "python3")
        self.env["PATH"] = str(selected) + os.pathsep + str(self.system)
        result = self.run_init("--config-only")
        self.assertEqual(result.returncode, 0, result.stderr)
        for phase in json.loads(self.output.read_text())["phases"]:
            for name in ("emacs", "cargo", "pdflatex", "python3"):
                self.assertEqual(phase[name], str(selected / name))

    def test_missing_clt_never_invokes_apple_stubs_even_in_dry_run(self):
        self.env["MOCK_CLT"] = "0"
        self.homebrew(self.arm)
        result = self.run_init("--dry-run")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("xcode-select --install", result.stderr)
        self.assertEqual(self.calls.read_text(), "")
        self.assertFalse(self.output.exists())

    def test_linux_keeps_original_paths(self):
        self.env["MOCK_PLATFORM"] = "Linux"
        self.homebrew(self.arm)
        result = self.run_init("--config-only")
        self.assertEqual(result.returncode, 0, result.stderr)
        for phase in json.loads(self.output.read_text())["phases"]:
            self.assertIsNone(phase["emacs"])
            self.assertIsNone(phase["cargo"])
            self.assertEqual(phase["python3"], str(self.system / "python3"))

    def test_standalone_emacs_setup_finds_homebrew_without_login_shell(self):
        self.homebrew(self.arm)
        self.command(self.arm / "bin/emacs", '''
case "$*" in
  *'(princ emacs-major-version)'*) printf '31' ;;
  *'(require (quote codex-ide))'*) printf 'validate\\n' >> "$MOCK_CALLS" ;;
  *) exit 98 ;;
esac
''')
        configuration = self.home / ".emacs.d"
        configuration.mkdir()
        for name in ("init.el", "packages.el", "check-config.el"):
            (configuration / name).write_text(";; fixture\n")
        result = subprocess.run([BASH, str(self.checkout / "scripts/setup-emacs.sh"),
                                 "--config-dir", str(configuration), "--check-only"],
                                env=self.env, cwd=self.root, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls.read_text().splitlines(), ["validate"])


if __name__ == "__main__":
    unittest.main()
