"""Exercise shared shell startup in disposable homes with fake integrations.

No real Homebrew, package managers or desktop integrations are invoked.
DOTFILES_TEST_BASH can select macOS's Bash 3.2; Zsh checks run when available.
"""

import errno
import fcntl
import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import subprocess
import tempfile
import termios
import time
import unittest


REPOSITORY = Path(__file__).resolve().parents[2]
BASH = shutil.which(os.environ.get("DOTFILES_TEST_BASH", "bash"))
ZSH = shutil.which(os.environ.get("DOTFILES_TEST_ZSH", "zsh"))


class ShellTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="dotfiles-shell-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.arm = self.root / "apple-homebrew"
        self.intel = self.root / "intel-homebrew"
        for module, files in {
            "shell": [".shellrc"], "bash": [".bashrc", ".bash_profile"],
            "zsh": [".zprofile", ".zshrc"],
        }.items():
            for name in files:
                source = (REPOSITORY / module / name).read_text()
                # Relocate fixed system paths into fixtures, retaining the
                # actual discovery logic and never reading host integrations.
                source = source.replace("/opt/homebrew", str(self.arm))
                source = source.replace("/usr/local/bin/brew", str(self.intel / "bin/brew"))
                source = source.replace("/usr/share/omarchy", str(self.root / "no-omarchy"))
                (self.home / name).write_text(source)
        self.env = {
            "HOME": str(self.home), "ZDOTDIR": str(self.home),
            "PATH": str(self.bin), "LANG": "C", "TERM": "dumb",
            "FZF_CALL_LOG": str(self.root / "fzf-calls"),
        }
        self.executable(self.bin / "uname", "printf '%s\\n' Darwin\n")
        self.executable(self.bin / "tty", "printf '%s\\n' /dev/tty\n")
        self.executable(self.bin / "fzf",
                        'printf "call\\n" >> "$FZF_CALL_LOG"\n'
                        "printf '%s\\n' 'FZF_LOADS=$(( ${FZF_LOADS:-0} + 1 ))'\n")

    def executable(self, path, body):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(0o755)

    def homebrew(self, prefix):
        prefix.mkdir(exist_ok=True)
        initialization = (f'export HOMEBREW_PREFIX="{prefix}"; '
                          f'export PATH="{prefix}/bin:{prefix}/sbin:$PATH"')
        self.executable(prefix / "bin/brew",
                        '[ "$1" = shellenv ] || exit 9\n'
                        f"printf '%s\\n' {shlex.quote(initialization)}\n")
        self.executable(prefix / "bin/emacs", "exit 0\n")

    def run_shell(self, code, shell=BASH, interactive=False, login=False, terminal=False):
        if shell == ZSH:
            arguments = [shell, "-d"]
            if login:
                arguments.append("-l")
        else:
            arguments = [shell, "--noprofile", "--norc"]
        if interactive:
            arguments.append("-i")
        arguments += ["-c", code]
        if terminal:
            # A controlling PTY is necessary to exercise ZLE/keybindings rather
            # than the non-TTY interactive mode used by exec-path-from-shell.
            master, slave = pty.openpty()
            try:
                with subprocess.Popen(
                    arguments, env=dict(self.env, TERM="xterm-256color"),
                    cwd=self.root, stdin=slave, stdout=slave, stderr=slave,
                    start_new_session=True,
                    preexec_fn=lambda: fcntl.ioctl(0, termios.TIOCSCTTY, 0),
                ) as process:
                    os.close(slave)
                    slave = None
                    os.set_blocking(master, False)
                    output = bytearray()
                    deadline = time.monotonic() + 10
                    try:
                        # Darwin can keep a PTY master open without reporting
                        # EOF after the shell exits. Drain only readable data,
                        # and stop once the child exited and no data is ready.
                        while True:
                            exited = process.poll() is not None
                            remaining = deadline - time.monotonic()
                            if remaining <= 0:
                                raise subprocess.TimeoutExpired(arguments, 10)
                            readable, _, _ = select.select(
                                [master], [], [], 0 if exited else min(0.1, remaining))
                            if not readable:
                                if exited:
                                    break
                                continue
                            try:
                                chunk = os.read(master, 4096)
                            except BlockingIOError:
                                continue
                            except OSError as error:
                                if error.errno == errno.EIO:
                                    break
                                raise
                            if not chunk:
                                break
                            output.extend(chunk)
                        process.wait(timeout=max(0.01, deadline - time.monotonic()))
                    except BaseException:
                        process.kill()
                        process.wait(timeout=3)
                        raise
                    result = subprocess.CompletedProcess(
                        arguments, process.returncode, output.decode(), "")
            finally:
                os.close(master)
                if slave is not None:
                    os.close(slave)
        else:
            result = subprocess.run(arguments, env=self.env, cwd=self.root,
                                    capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def test_bash_discovers_both_homebrew_roots_without_inherited_path(self):
        for prefix in (self.arm, self.intel):
            with self.subTest(prefix=prefix.name):
                self.homebrew(prefix)
                result = self.run_shell(
                    '. "$HOME/.bash_profile"; command -v emacs; '
                    'printf "fzf=%s\\n" "${FZF_LOADS:-0}"; '
                    'if alias emacs >/dev/null 2>&1; then exit 7; fi')
                self.assertEqual(result.stdout.splitlines(),
                                 [str(prefix / "bin/emacs"), "fzf=0"])
                shutil.rmtree(prefix)

    def test_selected_homebrew_is_retained(self):
        self.homebrew(self.arm)
        self.homebrew(self.intel)
        self.env["PATH"] = f"{self.intel}/bin:{self.bin}"
        result = self.run_shell('. "$HOME/.bash_profile"; command -v emacs')
        self.assertEqual(result.stdout.strip(), str(self.intel / "bin/emacs"))

    def test_repeated_shared_startup_keeps_homebrew_path_entries_unique(self):
        self.homebrew(self.arm)
        result = self.run_shell(
            '. "$HOME/.shellrc"; . "$HOME/.shellrc"; printf "%s\\n" "$PATH"')
        paths = result.stdout.strip().split(":")
        for path in (self.arm / "bin", self.arm / "sbin", self.home / ".local/bin"):
            self.assertEqual(paths.count(str(path)), 1)

    def test_linux_does_not_initialize_homebrew_and_path_is_idempotent(self):
        self.homebrew(self.arm)
        self.executable(self.bin / "uname", "printf '%s\\n' Linux\n")
        result = self.run_shell(
            '. "$HOME/.shellrc"; . "$HOME/.shellrc"; printf "%s\\n" "$PATH"')
        paths = result.stdout.strip().split(":")
        self.assertNotIn(str(self.arm / "bin"), paths)
        for path in (self.home / ".local/bin", self.home / ".bin", Path("/usr/local/sbin")):
            self.assertEqual(paths.count(str(path)), 1)

    def test_noninteractive_zprofile_keeps_local_hook_without_loading_zshrc(self):
        # .zprofile uses only syntax common to Bash and Zsh here, so this
        # regression also runs on Linux machines without Zsh installed.
        (self.home / ".zshrc").write_text("exit 8\n")
        (self.home / ".zprofile.local").write_text("export LOCAL_CHOICE=retained\n")
        self.homebrew(self.intel)
        result = self.run_shell(
            '. "$HOME/.zprofile"; command -v emacs; printf "%s\\n" "$LOCAL_CHOICE"')
        self.assertEqual(result.stdout.splitlines(),
                         [str(self.intel / "bin/emacs"), "retained"])

    def test_bash_interactive_integrations_and_aliases_still_load(self):
        result = self.run_shell(
            '. "$HOME/.bash_profile"; printf "fzf=%s\\n" "$FZF_LOADS"; alias emacs',
            interactive=True, terminal=True)
        self.assertIn("fzf=1", result.stdout)
        self.assertIn("emacs -nw", result.stdout)

    @unittest.skipUnless(ZSH, "Zsh is not installed")
    def test_zsh_login_loads_interactive_integrations_once(self):
        result = self.run_shell(
            'printf "fzf=%s\\n" "$FZF_LOADS"; alias emacs',
            shell=ZSH, login=True, interactive=True, terminal=True)
        self.assertIn("fzf=1", result.stdout)
        self.assertIn("emacs -nw", result.stdout)
        self.assertEqual(Path(self.env["FZF_CALL_LOG"]).read_text().splitlines(), ["call"])

    @unittest.skipUnless(ZSH, "Zsh is not installed")
    def test_zsh_non_tty_interactive_login_skips_fzf(self):
        result = self.run_shell(
            'printf "fzf=%s\\n" "${FZF_LOADS:-0}"; alias emacs',
            shell=ZSH, login=True, interactive=True)
        self.assertIn("fzf=0", result.stdout)
        self.assertIn("emacs -nw", result.stdout)
        self.assertFalse(Path(self.env["FZF_CALL_LOG"]).exists())

    @unittest.skipUnless(ZSH, "Zsh is not installed")
    def test_zsh_noninteractive_login_has_environment_without_integrations(self):
        self.homebrew(self.arm)
        result = self.run_shell(
            'command -v emacs; printf "fzf=%s\\n" "${FZF_LOADS:-0}"; '
            'if alias emacs >/dev/null 2>&1; then exit 7; fi',
            shell=ZSH, login=True)
        self.assertEqual(result.stdout.splitlines(),
                         [str(self.arm / "bin/emacs"), "fzf=0"])

    @unittest.skipUnless(ZSH, "Zsh is not installed")
    def test_zsh_supports_older_fzf_initialization(self):
        self.executable(self.bin / "fzf", "exit 1\n")
        (self.home / ".fzf.zsh").write_text("FZF_LOADS=legacy\n")
        result = self.run_shell('printf "%s\\n" "$FZF_LOADS"',
                                shell=ZSH, login=True, interactive=True, terminal=True)
        self.assertEqual(result.stdout.strip(), "legacy")


if __name__ == "__main__":
    unittest.main()
