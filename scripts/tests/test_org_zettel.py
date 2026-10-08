"""Regression tests using a temporary vault; no real notes or GUI launches."""

import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest import mock
from urllib.parse import quote


SPEC = importlib.util.spec_from_file_location(
    "org_zettel", Path(__file__).resolve().parents[1] / "org-zettel.py"
)
org_zettel = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(org_zettel)


class TemporaryVaultTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="org-zettel-test-")
        self.addCleanup(self.temp.cleanup)
        self.vault = Path(self.temp.name) / "vault"
        self.vault.mkdir()
        org_zettel._mtime_cache = None
        org_zettel.MTIME_CACHE_FILE = None

    def note(self, file_id, body="* 概要\n"):
        path = self.vault / file_id
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"#+TITLE: {path.stem}\n\n{body}", encoding="utf-8")
        return path

    def graph(self, **overrides):
        options = dict(include_daily=True, include_orphans=True, min_backlinks=0)
        options.update(overrides)
        return org_zettel.build_graph(self.vault, **options)


class GraphFileIdsTest(TemporaryVaultTest):
    def test_file_ids_include_notes_removed_by_every_display_filter(self):
        ids = ["Alpha.org", "daily/2026-09-26.org", "hidden/Beta.org", "orphan.org"]
        for file_id in ids:
            self.note(file_id)
        # A directory whose name ends in .org is not an existing note.
        (self.vault / "folder.org").mkdir()
        graph = self.graph(
            include_daily=False, include_orphans=False, min_backlinks=5,
            include_prefixes=["Alpha.org", "daily"], exclude_prefixes=["hidden"],
        )
        self.assertEqual(graph["nodes"], [])
        self.assertEqual(graph["file_ids"], sorted(ids))
        self.assertEqual(graph["org_root"], str(self.vault.resolve()))

    def test_missing_only_link_does_not_create_a_graph_node(self):
        self.note("Source.org", "* 概要\n[[file:Future.org][Future]]\n")
        graph = self.graph(include_orphans=False)
        self.assertEqual(graph["nodes"], [])
        self.assertEqual(graph["edges"], [])
        self.assertEqual(graph["file_ids"], ["Source.org"])
        self.assertFalse((self.vault / "Future.org").exists())

    def test_unfiltered_graph_retains_existing_link_behavior(self):
        self.note("Source.org", "* 概要\n[[file:Target.org]] [[file:Future.org]]\n")
        self.note("Target.org")
        graph = self.graph(include_orphans=False)
        self.assertEqual({node["id"] for node in graph["nodes"]}, {"Source.org", "Target.org"})
        self.assertEqual(graph["edges"], [{"source": "Source.org", "target": "Target.org"}])
        self.assertEqual(graph["file_ids"], ["Source.org", "Target.org"])


class OpenEmacsTest(TemporaryVaultTest):
    def setUp(self):
        super().setUp()
        handler_class = org_zettel.make_handler(self.vault, Path("unused"), {})
        self.handler = object.__new__(handler_class)
        self.handler._send_json = mock.Mock()
        self.launch = mock.patch.object(org_zettel.subprocess, "Popen").start()
        self.addCleanup(mock.patch.stopall)
        mock.patch.object(org_zettel, "_get_display_env", return_value={}).start()

    def request(self, file_id):
        self.handler.path = "/api/open-emacs/" + quote(file_id, safe="")
        self.handler.do_POST()

    def assert_launch(self, filepath):
        self.launch.assert_called_once()
        self.assertEqual(self.launch.call_args.args[0], [
            "alacritty", "--class", "org-zettel-edit", "-e", "emacsclient",
            "-t", "-a", "", str(filepath),
        ])
        self.handler._send_json.assert_called_once_with({"ok": True})

    def test_existing_note_opens_without_writing(self):
        filepath = self.note("Existing.org")
        before = (filepath.read_bytes(), filepath.stat().st_mtime_ns)
        self.request("Existing.org")
        self.assert_launch(filepath)
        self.assertEqual((filepath.read_bytes(), filepath.stat().st_mtime_ns), before)

    def test_missing_note_opens_without_creating_file_or_parents(self):
        file_id = "new folder/未作成のページ.org"
        self.request(file_id)
        self.assert_launch(self.vault / file_id)
        self.assertEqual(list(self.vault.iterdir()), [])

    def test_invalid_paths_never_launch(self):
        (self.vault / "directory.org").mkdir()
        for file_id in ("", "../Escape.org", "sub/../Escape.org", "/tmp/Escape.org",
                        "Null\0.org", "readme.txt", "directory.org"):
            with self.subTest(file_id=file_id):
                self.handler._send_json.reset_mock()
                self.request(file_id)
                self.handler._send_json.assert_called_once_with({"error": "invalid path"}, 400)
        self.launch.assert_not_called()

    def test_symlink_escape_never_launches(self):
        outside = Path(self.temp.name) / "outside"
        outside.mkdir()
        (self.vault / "alias").symlink_to(outside, target_is_directory=True)
        self.request("alias/Escape.org")
        self.launch.assert_not_called()
        self.handler._send_json.assert_called_once_with({"error": "invalid path"}, 400)
        self.assertFalse((outside / "Escape.org").exists())

    def test_missing_launcher_reports_its_actual_name(self):
        self.launch.side_effect = FileNotFoundError(2, "No such file or directory", "alacritty")
        self.request("Future.org")
        self.handler._send_json.assert_called_once_with({"error": "alacritty not found"}, 500)
        self.assertFalse((self.vault / "Future.org").exists())

    def test_other_launch_errors_are_json_errors(self):
        self.launch.side_effect = PermissionError("permission denied")
        self.request("Future.org")
        self.handler._send_json.assert_called_once_with(
            {"error": "could not launch Emacs: permission denied"}, 500,
        )
        self.assertFalse((self.vault / "Future.org").exists())


if __name__ == "__main__":
    unittest.main()
