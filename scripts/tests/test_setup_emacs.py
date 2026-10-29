"""Check setup orchestration using fake Emacs and temporary home directories."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SETUP = Path(__file__).resolve().parents[1] / "setup-emacs.sh"


class SetupEmacsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="dotfiles-emacs-setup-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.home = self.root / "home"
        self.config = self.home / ".config/emacs"
        self.config.mkdir(parents=True)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "calls"
        self.log.write_text("")
        for name in ("init.el", "packages.el", "check-config.el", "early-init.el"):
            (self.config / name).write_text(";; Fixture source; fake Emacs does not load it.\n")
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / ".config"),
                        XDG_STATE_HOME=str(self.root / "state"),
                        PATH=str(self.bin) + os.pathsep + os.defpath,
                        MOCK_LOG=str(self.log), EMACS=str(self.bin / "emacs"),
                        EMACSCLIENT=str(self.bin / "emacsclient"))
        self.env.pop("BASH_ENV", None)
        self.write_command("omarchy", "#!/usr/bin/env bash\nexit 0\n")
        self.write_command("emacs", '''#!/usr/bin/env bash
case "$*" in
  *'(princ emacs-major-version)'*) printf '31' ;;
  *'(my/install-dotfiles-emacs-packages)'*) printf 'packages\\n' >> "$MOCK_LOG" ;;
  *'(require (quote codex-ide))'*) printf 'validate\\n' >> "$MOCK_LOG" ;;
  *) printf 'Unexpected fake Emacs invocation: %s\\n' "$*" >&2; exit 90 ;;
esac
''')
        self.write_command("emacsclient", '''#!/usr/bin/env bash
printf 'client\\n' >> "$MOCK_LOG"
# A reload request can probe for a daemon, but fixtures have none.
exit 1
''')
        self.write_command("omarchy-emacs-setup", '''#!/usr/bin/env bash
set -eu
[[ "${OMARCHY_THEME_HEADLESS:-}" == 1 ]] || exit 91
[[ "${OMARCHY_THEME_SKIP_BACKGROUND:-}" == 1 ]] || exit 92
printf 'integration\\n' >> "$MOCK_LOG"
mkdir -p "$HOME/.config/emacs/themes"
: > "$HOME/.config/emacs/omarchy.el"
: > "$HOME/.config/emacs/themes/omarchy-theme.el"
''')

    def write_command(self, name, text):
        path = self.bin / name
        path.write_text(text)
        path.chmod(0o755)

    def complete_integration(self):
        (self.config / "themes").mkdir()
        (self.config / "omarchy.el").write_text(";; Existing integration\n")
        (self.config / "themes/omarchy-theme.el").write_text(";; Existing theme\n")

    def run_setup(self, *arguments):
        return subprocess.run(["bash", str(SETUP), "--config-dir", str(self.config), *arguments],
                              env=self.env, cwd=self.root, text=True, capture_output=True)

    def test_initial_setup_generates_theme_without_reloading_desktop_or_emacs(self):
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), ["integration", "packages", "validate"])
        self.assertTrue((self.config / "omarchy.el").is_file())
        self.assertTrue((self.config / "themes/omarchy-theme.el").is_file())

    def test_check_only_refuses_missing_integration_without_running_setup(self):
        result = self.run_setup("--check-only")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("integration is incomplete", result.stdout + result.stderr)
        self.assertEqual(self.log.read_text(), "")
        self.assertFalse((self.config / "omarchy.el").exists())

    def test_check_only_with_existing_integration_only_validates(self):
        self.complete_integration()
        result = self.run_setup("--check-only")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), ["validate"])

    def test_reload_flag_explicitly_probes_for_a_running_daemon(self):
        self.complete_integration()
        result = self.run_setup("--check-only", "--reload")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), ["validate", "client"])
        self.assertIn("No running Emacs daemon found", result.stdout)


if __name__ == "__main__":
    unittest.main()
