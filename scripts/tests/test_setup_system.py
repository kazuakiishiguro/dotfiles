"""Exercise missing-only provisioning with fake package-manager commands."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SETUP = Path(__file__).resolve().parents[1] / "setup-system.sh"
ALL_PACKAGES = {
    "git", "python", "curl", "fzf", "fcitx5-mozc", "emacs-wayland", "rust", "rust-analyzer",
    "lldb", "python-jedi", "python-rope", "python-flake8", "python-black",
    "texlive-latexrecommended", "pandoc-cli", "omarchy-emacs",
}


class SetupSystemTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.installed = self.root / "installed"
        self.log = self.root / "calls"
        self.installed.write_text("")
        self.log.write_text("")
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.defpath,
                        MOCK_INSTALLED=str(self.installed), MOCK_LOG=str(self.log))
        self.write_command("pacman", '''#!/usr/bin/env bash
[[ "$1" == -Q ]] || exit 90
while IFS= read -r package; do
    [[ "$package" == "$2" ]] && exit 0
done < "$MOCK_INSTALLED"
exit 1
''')
        self.write_command("omarchy", '''#!/usr/bin/env bash
printf '%s\\n' "omarchy $*" >> "$MOCK_LOG"
[[ "$1" == pkg ]] || exit 91
shift
[[ "$1" != aur ]] || shift
[[ "$1" == add ]] || exit 92
shift
printf '%s\\n' "$@" >> "$MOCK_INSTALLED"
''')
        self.write_command("yay", "#!/usr/bin/env bash\nexit 93\n")
        for executable in ("git", "python3", "curl", "fzf", "emacs", "cargo", "rustc",
                           "rustfmt", "rust-analyzer", "lldb", "flake8", "black", "pdflatex", "pandoc"):
            self.write_command(executable, "#!/usr/bin/env bash\nexit 0\n")

    def write_command(self, name, content):
        target = self.bin / name
        target.write_text(content)
        target.chmod(0o755)

    def install(self, packages):
        self.installed.write_text("".join(package + "\n" for package in sorted(packages)))

    def run_setup(self, *arguments):
        return subprocess.run(["bash", str(SETUP), "--profile", "omarchy", *arguments],
                              env=self.env, cwd=self.root, text=True, capture_output=True)

    def test_installs_only_missing_packages_then_reruns_without_writes(self):
        self.install(ALL_PACKAGES - {"python-jedi", "python-rope"})
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), ["omarchy pkg add python-jedi python-rope"])
        self.log.write_text("")
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text(), "")

    def test_dry_run_never_calls_package_manager_mutations(self):
        self.install(ALL_PACKAGES - {"python-jedi", "omarchy-emacs"})
        before = self.installed.read_bytes()
        result = self.run_setup("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("omarchy pkg add python-jedi", result.stdout)
        self.assertIn("omarchy pkg aur add omarchy-emacs", result.stdout)
        self.assertEqual(self.log.read_text(), "")
        self.assertEqual(self.installed.read_bytes(), before)

    def test_skip_emacs_does_not_install_editor_or_language_tools(self):
        self.install({"git", "python", "curl", "fzf", "fcitx5-mozc"})
        result = self.run_setup("--skip-emacs")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text(), "")

    def test_missing_integration_uses_specific_aur_route(self):
        self.install(ALL_PACKAGES - {"omarchy-emacs"})
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), ["omarchy pkg aur add omarchy-emacs"])

    def test_plain_emacs_conflict_stops_before_any_package_changes(self):
        self.install({"emacs"})
        before = self.installed.read_bytes()
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires replacing", result.stderr)
        self.assertIn("sudo pacman -S emacs-wayland", result.stderr)
        self.assertEqual(self.log.read_text(), "")
        self.assertEqual(self.installed.read_bytes(), before)

    def test_dry_run_reports_plain_emacs_conflict_without_changes(self):
        self.install({"emacs"})
        before = self.installed.read_bytes()
        result = self.run_setup("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("emacs-wayland", result.stderr)
        self.assertIn("resolve this Emacs package conflict", result.stdout)
        self.assertEqual(self.log.read_text(), "")
        self.assertEqual(self.installed.read_bytes(), before)

    def test_skip_emacs_retains_plain_emacs_without_replacement(self):
        self.install({"git", "python", "curl", "fzf", "fcitx5-mozc", "emacs"})
        before = self.installed.read_bytes()
        result = self.run_setup("--skip-emacs")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text(), "")
        self.assertEqual(self.installed.read_bytes(), before)

    def test_existing_external_rust_toolchain_is_retained(self):
        self.install(ALL_PACKAGES - {"rust", "rust-analyzer"})
        for executable in ("cargo", "rustc", "rustfmt", "rust-analyzer"):
            self.write_command(executable, "#!/usr/bin/env bash\nexit 0\n")
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text(), "")

    def test_package_failure_stops_before_next_phase(self):
        self.install(ALL_PACKAGES - {"python-jedi", "omarchy-emacs"})
        self.write_command("omarchy", "#!/usr/bin/env bash\nprintf '%s\\n' \"$*\" >> \"$MOCK_LOG\"\nexit 7\n")
        result = self.run_setup()
        self.assertEqual(result.returncode, 7)
        self.assertEqual(self.log.read_text().splitlines(), ["pkg add python-jedi"])

    def test_existing_rustup_adds_missing_components_instead_of_conflicting_rust(self):
        self.install((ALL_PACKAGES - {"rust", "rust-analyzer"}) | {"rustup"})
        component_marker = self.root / "components-added"
        self.env["MOCK_COMPONENTS"] = str(component_marker)
        for executable in ("rustfmt", "rust-analyzer"):
            self.write_command(executable, '#!/usr/bin/env bash\n[[ -f "$MOCK_COMPONENTS" ]]\n')
        self.write_command("cargo", '''#!/usr/bin/env bash
[[ "$1" != clippy || -f "$MOCK_COMPONENTS" ]]
''')
        self.write_command("rustup", '''#!/usr/bin/env bash
if [[ "$1 $2" == 'show active-toolchain' ]]; then
    echo stable-x86_64-unknown-linux-gnu
elif [[ "$1 $2" == 'component add' ]]; then
    printf '%s\\n' "rustup $*" >> "$MOCK_LOG"
    touch "$MOCK_COMPONENTS"
else
    exit 99
fi
''')
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), ["rustup component add rustfmt rust-analyzer clippy"])
        self.assertNotIn("\nrust\n", "\n" + self.installed.read_text())

    def test_rustup_without_active_toolchain_fails_before_package_mutations(self):
        self.install(ALL_PACKAGES | {"rustup"})
        self.write_command("rustup", "#!/usr/bin/env bash\nexit 1\n")
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("rustup default stable", result.stderr)
        self.assertEqual(self.log.read_text(), "")

    def test_python_shadowing_is_reported_after_packages_are_installed(self):
        self.install(ALL_PACKAGES - {"python-jedi"})
        self.write_command("python3", '''#!/usr/bin/env bash
[[ "$1" == --version ]]
''')
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot be imported", result.stderr)
        self.assertIn("virtualenv or mise", result.stderr)
        self.assertIn("omarchy pkg add python-jedi", self.log.read_text())

    def test_nonfunctional_rust_shim_is_not_counted_as_working_tool(self):
        self.install(ALL_PACKAGES)
        self.write_command("rustfmt", "#!/usr/bin/env bash\nexit 1\n")
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not working: rustfmt", result.stderr)


if __name__ == "__main__":
    unittest.main()
