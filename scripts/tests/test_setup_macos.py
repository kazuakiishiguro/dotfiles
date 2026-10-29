"""macOS provisioning uses only fixture commands, homes, and package state."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1]
BASH = os.environ.get("DOTFILES_TEST_BASH", "bash")
FORMULAE = {
    "git": ["git"], "python": ["python3"], "curl": ["curl"], "fzf": ["fzf"],
    "gnupg": ["gpg"], "emacs": ["emacs"], "pandoc": ["pandoc"],
    "rust": ["cargo", "rustc", "rustfmt"], "rust-analyzer": ["rust-analyzer"],
}

DISPATCH = r'''
import json
import os
from pathlib import Path
import sys

state_path = Path(os.environ["MOCK_STATE"])
state = json.loads(state_path.read_text())
root = state_path.parent
binary = root / "bin"
name = Path(sys.argv[0]).name
arguments = sys.argv[1:]
if name == "python" and arguments[:1] == ["-B"]:
    arguments = arguments[1:]
log = root / "mutations"

def save():
    state_path.write_text(json.dumps(state))

def record():
    with log.open("a") as output:
        output.write(json.dumps([name, *arguments]) + "\n")

def create_tool(tool, directory=binary):
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / tool
    if not target.exists():
        target.symlink_to(root / "dispatch")
    if tool in state["broken"]:
        state["broken"].remove(tool)

if name == "uname":
    print("Darwin")
elif name == "xcode-select":
    if not state["clt"]:
        sys.exit(1)
    print(root / "Developer")
elif name == "brew":
    if arguments == ["--version"]:
        print("Homebrew fixture")
    elif arguments[:1] == ["list"]:
        category = "casks" if arguments[1] == "--cask" else "formulae"
        sys.exit(0 if arguments[-1] in state[category] else 1)
    elif arguments[:1] == ["install"]:
        record()
        for variable in ("HOMEBREW_NO_AUTO_UPDATE", "HOMEBREW_NO_INSTALL_UPGRADE", "HOMEBREW_NO_INSTALL_CLEANUP"):
            assert os.environ.get(variable) == "1", variable
        if state.get("brew_failure"):
            sys.exit(7)
        category = "casks" if "--cask" in arguments else "formulae"
        for package in arguments[1:]:
            if package.startswith("--"):
                continue
            state[category].append(package)
            for tool in state["formula_tools"].get(package, []):
                create_tool(tool)
            if package == "basictex":
                create_tool("pdflatex", root / "texbin")
            elif package == "emacs-app":
                create_tool("emacs")
                create_tool("emacsclient")
        save()
    else:
        raise RuntimeError(arguments)
elif name == "rustup":
    if arguments == ["show", "active-toolchain"]:
        sys.exit(0 if state["active_toolchain"] else 1)
    elif arguments == ["component", "list", "--installed"]:
        print("\n".join(state["components"]))
    elif arguments[:2] == ["component", "add"]:
        record()
        state["components"].extend(arguments[2:])
        for component in arguments[2:]:
            if component != "rust-src":
                create_tool("cargo" if component == "clippy" else component)
            if component == "clippy":
                state["clippy"] = True
        save()
    else:
        raise RuntimeError(arguments)
elif name == "emacs" and name not in state["broken"]:
    print(state["emacs_major"])
elif name == "cargo" and arguments[:1] == ["clippy"]:
    sys.exit(0 if state["clippy"] else 1)
elif name == "python3" and arguments[:2] == ["-m", "venv"]:
    record()
    environment = Path(arguments[2])
    environment.mkdir(parents=True)
    (environment / "pyvenv.cfg").write_text("fixture virtualenv\n")
    create_tool("python", environment / "bin")
elif name == "python" and arguments[:2] == ["-m", "pip"]:
    record()
    if state.get("pip_failure"):
        sys.exit(8)
    state["modules"].extend(arg for arg in arguments[3:] if not arg.startswith("--"))
    create_tool("black", Path(sys.argv[0]).parent)
    create_tool("flake8", Path(sys.argv[0]).parent)
    save()
elif name == "python" and arguments[:1] == ["-c"]:
    modules = arguments[1].removeprefix("import ").replace(",", "").split()
    sys.exit(0 if all(module in state["modules"] for module in modules) else 1)
else:
    sys.exit(1 if name in state["broken"] else 0)
'''


class SetupMacosTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.home = self.root / "home"
        self.home.mkdir()
        (self.root / "Developer").mkdir()
        self.state_path = self.root / "state.json"
        self.log = self.root / "mutations"
        self.log.write_text("")
        self.state = {
            "formulae": [], "casks": ["basictex", "font-jetbrains-mono-nerd-font"],
            "formula_tools": FORMULAE, "broken": [], "clt": True,
            "active_toolchain": True, "components": ["rust-src"], "clippy": True,
            "emacs_major": 31, "modules": ["jedi", "rope", "flake8", "black"],
        }
        self.save()
        dispatch = self.root / "dispatch"
        dispatch.write_text(f"#!{sys.executable}\n" + DISPATCH)
        dispatch.chmod(0o755)
        for executable in {"uname", "xcode-select", "brew", "rustup", "lldb", "pdflatex",
                           *[tool for tools in FORMULAE.values() for tool in tools]}:
            (self.bin / executable).symlink_to(dispatch)
        for executable in ("env", "bash", "dirname"):
            (self.bin / executable).symlink_to(shutil.which(executable))
        self.environment = self.home / ".local/share/dotfiles/python"
        (self.environment / "bin").mkdir(parents=True)
        (self.environment / "pyvenv.cfg").write_text("fixture virtualenv\n")
        for executable in ("python", "black", "flake8"):
            (self.environment / "bin" / executable).symlink_to(dispatch)
        self.env = dict(os.environ, PATH=str(self.bin), HOME=str(self.home),
                        MOCK_STATE=str(self.state_path))
        for variable in ("EMACS", "XDG_DATA_HOME"):
            self.env.pop(variable, None)
        self.setup = self.root / "setup-macos.sh"
        # All platform-fixed paths belong to the fixture; even a Mac runner
        # cannot accidentally consult its own Homebrew or TeX installation.
        source = (SCRIPTS / "setup-macos.sh").read_text()
        source = source.replace("/opt/homebrew", str(self.root / "opt/homebrew"))
        source = source.replace("/usr/local", str(self.root / "usr/local"))
        source = source.replace("/Library/TeX/texbin", str(self.root / "texbin"))
        source = source.replace('"/Applications/Emacs.app"',
                                '"' + str(self.root / "Applications/Emacs.app") + '"')
        self.setup.write_text(source)

    def save(self):
        self.state_path.write_text(json.dumps(self.state))

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def run_setup(self, *arguments):
        self.save()
        return subprocess.run([BASH, str(self.setup), *arguments], env=self.env,
                              cwd=self.root, text=True, capture_output=True)

    def test_ready_host_reruns_without_mutations(self):
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [])

    def test_missing_formula_is_installed_without_upgrade_or_cleanup(self):
        (self.bin / "fzf").unlink()
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [["brew", "install", "--formula", "--force-bottle", "fzf"]])

    def test_dry_run_has_no_mutations_or_environment_creation(self):
        shutil.rmtree(self.environment)
        self.state["modules"] = []
        self.state["casks"] = []
        self.state["broken"] = ["rust-analyzer", "fzf"]
        (self.bin / "pdflatex").unlink()
        result = self.run_setup("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("brew install --formula", result.stdout)
        self.assertIn("basictex", result.stdout)
        self.assertIn("rustup component add rust-analyzer", result.stdout)
        self.assertIn("-m pip install", result.stdout)
        self.assertFalse(self.environment.exists())
        self.assertEqual(self.calls(), [])

    def test_dry_run_import_probes_do_not_write_python_bytecode(self):
        modules = self.root / "backend-modules"
        modules.mkdir()
        for name in ("jedi", "rope", "flake8", "black"):
            (modules / (name + ".py")).write_text("PRESENT = True\n")
        self.env["PYTHONPATH"] = str(modules)
        for variable in ("PYTHONDONTWRITEBYTECODE", "PYTHONPYCACHEPREFIX"):
            self.env.pop(variable, None)
        backend = self.environment / "bin/python"
        backend.unlink()
        backend.write_text("#!/bin/sh\nexec " + shlex.quote(sys.executable) + ' "$@"\n')
        backend.chmod(0o755)
        result = self.run_setup("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("pip install", result.stdout)
        self.assertFalse((modules / "__pycache__").exists())
        self.assertEqual(self.calls(), [])
        # Confirm the fixture would expose an unguarded import: ordinary
        # Python in this same environment does create a bytecode cache.
        subprocess.run([sys.executable, "-c", "import jedi"], env=self.env, check=True)
        self.assertTrue((modules / "__pycache__").is_dir())

    def test_skip_emacs_leaves_toolchains_backends_and_editor_untouched(self):
        shutil.rmtree(self.environment)
        self.state["modules"] = []
        self.state["casks"] = []
        self.state["broken"] = ["emacs", "cargo", "lldb"]
        self.state["active_toolchain"] = False
        result = self.run_setup("--skip-emacs")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.environment.exists())
        self.assertEqual(self.calls(), [])

    def test_broken_editor_stops_before_any_package_installation(self):
        self.state["broken"] = ["emacs", "fzf"]
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("it was not replaced", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_older_editor_stops_without_replacement(self):
        self.state["emacs_major"] = 28
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Emacs 29 or newer", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_fresh_editor_gets_cocoa_emacs_cask(self):
        (self.bin / "emacs").unlink()
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [["brew", "install", "--cask", "emacs-app"]])
        self.assertTrue((self.bin / "emacsclient").exists())

    def test_installed_emacs_cask_without_command_requires_explicit_selection(self):
        (self.bin / "emacs").unlink()
        self.state["casks"].append("emacs-app")
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("application was not replaced", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_existing_emacs_app_without_command_is_retained(self):
        (self.bin / "emacs").unlink()
        application = self.root / "Applications/Emacs.app"
        application.mkdir(parents=True)
        marker = application / "personal-app"
        marker.write_text("keep this app")
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("application was not replaced", result.stderr)
        self.assertEqual(marker.read_text(), "keep this app")
        self.assertEqual(self.calls(), [])

    def test_missing_components_use_current_rustup_toolchain(self):
        self.state["broken"] = ["rust-analyzer"]
        self.state["components"] = []
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [["rustup", "component", "add", "rust-analyzer", "rust-src"]])

    def test_inactive_rustup_stops_before_package_writes(self):
        self.state["active_toolchain"] = False
        self.state["broken"] = ["fzf"]
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no toolchain was switched", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_existing_nonrustup_toolchain_is_preserved(self):
        (self.bin / "rustup").unlink()
        (self.bin / "rust-analyzer").unlink()
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [["brew", "install", "--formula", "--force-bottle", "rust-analyzer"]])

    def test_hidden_home_rustup_does_not_replace_selected_nonrustup_cargo(self):
        (self.bin / "rustup").unlink()
        hidden_bin = self.home / ".cargo/bin"
        hidden_bin.mkdir(parents=True)
        (hidden_bin / "rustup").symlink_to(self.root / "dispatch")
        hidden_cargo = hidden_bin / "cargo"
        hidden_cargo.write_text("#!/bin/sh\nexit 77\n")
        hidden_cargo.chmod(0o755)
        self.state["active_toolchain"] = False
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [])

    def test_fresh_rust_uses_bottled_formulae(self):
        for executable in ("rustup", "cargo", "rustc", "rustfmt", "rust-analyzer"):
            (self.bin / executable).unlink()
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [["brew", "install", "--formula", "--force-bottle", "rust", "rust-analyzer"]])

    def test_python_packages_live_only_in_managed_virtualenv(self):
        shutil.rmtree(self.environment)
        self.state["modules"] = []
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [
            ["python3", "-m", "venv", str(self.environment)],
            ["python", "-m", "pip", "install", "--disable-pip-version-check", "jedi", "rope", "flake8", "black"],
        ])
        self.state = json.loads(self.state_path.read_text())
        self.log.write_text("")
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [])

    def test_invalid_virtualenv_is_retained_before_any_install(self):
        (self.environment / "pyvenv.cfg").unlink()
        self.state["broken"] = ["fzf"]
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("it was not overwritten", result.stderr)
        self.assertTrue((self.environment / "bin/python").exists())
        self.assertEqual(self.calls(), [])

    def test_basictex_path_is_available_immediately_after_install(self):
        (self.bin / "pdflatex").unlink()
        self.state["casks"] = []
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [["brew", "install", "--cask", "basictex", "font-jetbrains-mono-nerd-font"]])

    def test_missing_developer_tools_stops_before_apple_launchers(self):
        self.state["clt"] = False
        result = self.run_setup("--dry-run")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("xcode-select --install", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_package_failure_stops_before_virtualenv_install(self):
        (self.bin / "fzf").unlink()
        self.state["modules"] = []
        self.state["brew_failure"] = True
        result = self.run_setup()
        self.assertEqual(result.returncode, 7)
        self.assertEqual(len(self.calls()), 1)

    def test_macos_profile_dispatches_to_helper(self):
        (self.root / "setup-system.sh").write_text((SCRIPTS / "setup-system.sh").read_text())
        result = subprocess.run([BASH, str(self.root / "setup-system.sh"), "--profile", "macos",
                                 "--skip-emacs", "--dry-run"], env=self.env, cwd=self.home,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("macOS prerequisite preview", result.stdout)
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
