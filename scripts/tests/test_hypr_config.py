"""Load shared Hyprland Lua against fixture modules, without a desktop session."""

import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest


LUA = shutil.which("lua")
CONFIG = Path(__file__).resolve().parents[2] / "config/.config/hypr/hyprland.lua"
EXPECTED = "bootstrap,defaults,monitors,input,bindings,looknfeel,autostart,toggles"


@unittest.skipUnless(LUA, "Lua is required for Hyprland configuration fixtures")
class HyprConfigTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="dotfiles-hypr-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / "home"
        self.packaged = self.root / "packaged-omarchy"
        self.write(self.packaged / "default/hypr/bootstrap.lua", '''
table.insert(events, "bootstrap")
package.path = (os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/?.lua;"
''')
        self.write(self.packaged / "default/hypr/omarchy.lua", 'table.insert(events, "defaults")\n')
        self.write(self.packaged / "default/hypr/toggles.lua", 'table.insert(events, "toggles")\n')
        for name in ("monitors", "input", "bindings", "looknfeel", "autostart"):
            self.write(self.home / f".config/hypr/{name}.lua", f'table.insert(events, "{name}")\n')
        self.entry = self.root / "hyprland.lua"
        self.entry.write_text(CONFIG.read_text())
        self.runner = self.root / "runner.lua"
        self.runner.write_text('''
local root, home, packaged, omarchy_env, entry = table.unpack(arg)
local virtual = "/usr/share/omarchy"
local real_open = io.open
local function fixture_path(path)
  if path == virtual or path:sub(1, #virtual + 1) == virtual .. "/" then
    path = packaged .. path:sub(#virtual + 1)
  end
  assert(path:sub(1, #root + 1) == root .. "/", "Access outside fixture: " .. path)
  return path
end
os.getenv = function(name)
  if name == "HOME" then return home end
  if name == "OMARCHY_PATH" then return omarchy_env end
end
io.open = function(path, mode) return real_open(fixture_path(path), mode) end
dofile = function(path) return assert(loadfile(fixture_path(path)))() end
-- Resolve the script's actual package.path, mapping only the packaged prefix.
-- No system module searcher remains, so real desktop modules cannot execute.
package.path = ""
package.searchers = {function(name)
  local search = package.path:gsub(virtual, function() return packaged end)
  local path, message = package.searchpath(name, search)
  if not path then return message end
  return assert(loadfile(fixture_path(path))), path
end}
events = {}
dofile(entry)
print(table.concat(events, ","))
''')

    def write(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def run_config(self, omarchy_path=None):
        return subprocess.run(
            [LUA, "-E", str(self.runner), str(self.root), str(self.home), str(self.packaged),
             str(omarchy_path or self.packaged), str(self.entry)],
            cwd=self.root, text=True, capture_output=True,
        )

    def test_missing_machine_overrides_loads_shared_modules(self):
        result = self.run_config()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), EXPECTED)

    def test_machine_overrides_execute_after_all_shared_modules(self):
        self.write(self.home / ".config/hypr/local.lua", '''
assert(events[#events] == "toggles", "Shared configuration is incomplete")
table.insert(events, "local")
''')
        result = self.run_config()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), EXPECTED + ",local")

    def test_machine_override_errors_are_reported(self):
        self.write(self.home / ".config/hypr/local.lua", 'error("fixture local configuration failure")\n')
        result = self.run_config()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture local configuration failure", result.stderr)

    def test_stale_environment_falls_back_to_detected_packaged_install(self):
        result = self.run_config(self.root / "removed-omarchy")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), EXPECTED)


if __name__ == "__main__":
    unittest.main()
