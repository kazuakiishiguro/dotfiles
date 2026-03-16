#!/usr/bin/env python3
"""Scan ~/org/ .org files and produce a self-contained zettelkasten viewer.

Usage:
    cd ~/org && python3 org-zettel.py && xdg-open org-zettel-view.html

Live server with inline editing:
    cd ~/org && python3 org-zettel.py --serve

Or add shell aliases:
    alias org-zettel='cd ~/org && python3 org-zettel.py && xdg-open org-zettel-view.html'
    alias org-serve='cd ~/org && python3 org-zettel.py --serve'

Flags:
    --serve              Start live HTTP server with editing support
    --port PORT          Server port (default: 8080)
    --include-daily      Include daily notes (excluded by default)
    --include-orphans    Include unlinked nodes (excluded by default)
    --min-backlinks N    Only show nodes with >= N backlinks
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import unquote

SCRIPT_DIR = Path(__file__).parent.resolve()
ORG_DIR = Path.cwd()
TEMPLATE = SCRIPT_DIR / "org-zettel.html"
OUTPUT = ORG_DIR / "org-zettel-view.html"

LINK_RE = re.compile(r"\[\[file:(.*?\.org)(?:::[^\]]*?)?\]")
TITLE_RE = re.compile(r"^#\+TITLE:\s*(.+)", re.IGNORECASE)
DATE_RE = re.compile(r"^#\+DATE:\s*(.+)", re.IGNORECASE)
FILETAGS_RE = re.compile(r"^#\+FILETAGS:\s*(.+)", re.IGNORECASE)
BACKLINKS_HEADING_RE = re.compile(r"^\*\s+Backlinks\s*\((\d+)\)", re.IGNORECASE)


def classify(path: str) -> str:
    """Classify an org file by its relative path."""
    parts = Path(path).parts
    if parts[0] == "daily":
        return "daily"
    if parts[0] == "clippings":
        return "clippings"
    if parts[0] == "references":
        return "references"
    return "root"


MTIME_CACHE_FILE = None
_mtime_cache = None


def _load_mtime_cache(org_dir: Path):
    global MTIME_CACHE_FILE, _mtime_cache
    MTIME_CACHE_FILE = org_dir / ".org-zettel-mtime.json"
    if _mtime_cache is not None:
        return
    try:
        _mtime_cache = json.loads(MTIME_CACHE_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        _mtime_cache = {}


def _save_mtime_cache():
    if MTIME_CACHE_FILE and _mtime_cache is not None:
        MTIME_CACHE_FILE.write_text(
            json.dumps(_mtime_cache, ensure_ascii=False), encoding="utf-8"
        )


def _content_hash(text: str, backlinks_re) -> str:
    """Hash file content excluding the Backlinks section."""
    lines = []
    for line in text.splitlines():
        if backlinks_re.match(line):
            break
        lines.append(line)
    content = "\n".join(lines)
    return hashlib.md5(content.encode("utf-8")).hexdigest()


def parse_org_file(filepath: Path, org_dir: Path) -> dict:
    """Extract metadata and outgoing links from a single .org file."""
    rel = filepath.relative_to(org_dir).as_posix()

    title = None
    date = None
    tags = []
    backlink_count = 0
    links = []
    in_backlinks = False
    seen_frontmatter = False
    in_body = False
    body_lines = []

    try:
        text = filepath.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None

    for line in text.splitlines():
        # Check for Backlinks heading — stop collecting links after this
        m = BACKLINKS_HEADING_RE.match(line)
        if m:
            backlink_count = int(m.group(1))
            in_backlinks = True
            continue

        # Parse front-matter
        if not in_backlinks:
            is_frontmatter = line.startswith("#+")
            if is_frontmatter:
                seen_frontmatter = True

            if title is None:
                m = TITLE_RE.match(line)
                if m:
                    title = m.group(1).strip()
                    continue

            if date is None:
                m = DATE_RE.match(line)
                if m:
                    date = m.group(1).strip().strip("[]<>")
                    continue

            if not tags:
                m = FILETAGS_RE.match(line)
                if m:
                    raw = m.group(1).strip().strip(":")
                    tags = [t for t in raw.split(":") if t]
                    continue

            # Collect body lines between frontmatter and Backlinks
            if not in_body and seen_frontmatter and not is_frontmatter and line.strip():
                in_body = True

            if in_body:
                body_lines.append(line)

        # Collect links (only before Backlinks section)
        if not in_backlinks:
            for lm in LINK_RE.finditer(line):
                link_target = lm.group(1)
                # Resolve relative path
                target_path = (filepath.parent / link_target).resolve()
                try:
                    target_rel = target_path.relative_to(org_dir).as_posix()
                except ValueError:
                    continue
                links.append(target_rel)

    # Strip leading/trailing blank lines and cap at 50 lines
    while body_lines and not body_lines[0].strip():
        body_lines.pop(0)
    while body_lines and not body_lines[-1].strip():
        body_lines.pop()
    body_lines = body_lines[:50]

    # Compute mtime based on content hash (excluding backlinks)
    content_h = _content_hash(text, BACKLINKS_HEADING_RE)
    cached = _mtime_cache.get(rel) if _mtime_cache else None
    fs_mtime = os.path.getmtime(filepath)
    if cached and cached.get("hash") == content_h:
        mtime = cached["mtime"]
    else:
        mtime = fs_mtime
        if _mtime_cache is not None:
            _mtime_cache[rel] = {"hash": content_h, "mtime": mtime}
    mtime_iso = time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(mtime))

    return {
        "id": rel,
        "title": title or Path(rel).stem.replace("-", " ").replace("_", " "),
        "date": date,
        "tags": tags,
        "category": classify(rel),
        "backlinks": backlink_count,
        "links": links,
        "content": "\n".join(body_lines),
        "mtime": mtime_iso,
    }


def build_graph(org_dir: Path, include_daily: bool, include_orphans: bool, min_backlinks: int):
    """Scan all .org files and build the graph data structure."""
    _load_mtime_cache(org_dir)
    org_files = sorted(org_dir.rglob("*.org"))
    print(f"Scanning {len(org_files)} .org files...", file=sys.stderr)

    raw_nodes = {}
    for f in org_files:
        node = parse_org_file(f, org_dir)
        if node:
            raw_nodes[node["id"]] = node

    # Filter by category
    if not include_daily:
        raw_nodes = {k: v for k, v in raw_nodes.items() if v["category"] != "daily"}

    # Build edges (filter non-existent targets and self-links)
    edges = []
    edge_set = set()
    for nid, node in raw_nodes.items():
        for target in node["links"]:
            if target in raw_nodes and target != nid:
                key = (nid, target)
                if key not in edge_set:
                    edge_set.add(key)
                    edges.append({"source": nid, "target": target})

    # Compute in-degree for nodes that don't have an explicit backlink count
    in_degree = {}
    for e in edges:
        in_degree[e["target"]] = in_degree.get(e["target"], 0) + 1

    for nid, node in raw_nodes.items():
        if node["backlinks"] == 0:
            node["backlinks"] = in_degree.get(nid, 0)

    # Filter orphans
    if not include_orphans:
        connected = set()
        for e in edges:
            connected.add(e["source"])
            connected.add(e["target"])
        raw_nodes = {k: v for k, v in raw_nodes.items() if k in connected}
        edges = [e for e in edges if e["source"] in raw_nodes and e["target"] in raw_nodes]

    # Filter by min backlinks
    if min_backlinks > 0:
        raw_nodes = {k: v for k, v in raw_nodes.items() if v["backlinks"] >= min_backlinks}
        edges = [e for e in edges if e["source"] in raw_nodes and e["target"] in raw_nodes]

    # Collect categories and tags
    categories = sorted(set(n["category"] for n in raw_nodes.values()))
    all_tags = sorted(set(t for n in raw_nodes.values() for t in n["tags"]))

    # Build output nodes (drop the links field)
    out_nodes = []
    for n in raw_nodes.values():
        out_nodes.append({
            "id": n["id"],
            "title": n["title"],
            "date": n["date"],
            "tags": n["tags"],
            "category": n["category"],
            "backlinks": n["backlinks"],
            "content": n["content"],
            "mtime": n["mtime"],
        })

    print(f"Nodes: {len(out_nodes)}  Edges: {len(edges)}  Tags: {len(all_tags)}", file=sys.stderr)

    _save_mtime_cache()

    return {
        "nodes": out_nodes,
        "edges": edges,
        "categories": categories,
        "tags": all_tags,
    }


def make_handler(org_dir, template_path, build_args):
    _load_mtime_cache(org_dir)

    _DATE_BASENAME_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

    def _in_sync_scope(file_id):
        """Check if file is in sync scope (not a date-named file)."""
        basename = Path(file_id).stem
        return not _DATE_BASENAME_RE.match(basename)

    def _title_to_filename(title):
        """Convert a title to a filename: capitalize first letter, spaces to underscores."""
        if not title:
            return title
        return title[0].upper() + title[1:].replace(" ", "_")

    def _update_backlinks(org_dir, old_base, new_base, old_title, new_title):
        """Scan all .org files and rewrite links from old_base to new_base.

        Returns count of modified files.
        """
        modified = 0
        for org_file in org_dir.rglob("*.org"):
            try:
                text = org_file.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            original = text
            # Rewrite full org links: [[file:...old_base.org][desc]] and [[file:...old_base.org]]
            link_re = re.compile(
                r'\[\[file:([^\]]*?)' + re.escape(old_base + '.org')
                + r'\](?:\[([^\]]*?)\])?\]'
            )
            def _rewrite_link(m):
                prefix = m.group(1)
                desc = m.group(2)
                new_link = '[[file:' + prefix + new_base + '.org]'
                if desc is not None:
                    if desc == old_title and old_title != new_title:
                        desc = new_title
                    new_link += '[' + desc + ']'
                return new_link + ']'
            text = link_re.sub(_rewrite_link, text)
            if text != original:
                org_file.write_text(text, encoding="utf-8")
                modified += 1
        return modified

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            print(format % args, file=sys.stderr)

        def _cors_headers(self):
            self.send_header('Access-Control-Allow-Origin', '*')

        def _send_json(self, data, status=200):
            body = json.dumps(data, ensure_ascii=False).encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self._cors_headers()
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _send_text(self, text, status=200):
            body = text.encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self._cors_headers()
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _send_html(self, html, status=200):
            body = html.encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self._cors_headers()
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _resolve_id(self, path_prefix):
            """Extract and validate file ID from URL path."""
            raw = self.path[len(path_prefix):]
            file_id = unquote(raw)
            # Path traversal protection
            resolved = (org_dir / file_id).resolve()
            org_root = str(org_dir.resolve())
            if not (str(resolved) == org_root or str(resolved).startswith(org_root + os.sep)):
                return None, None
            if not resolved.suffix == '.org':
                return None, None
            return file_id, resolved

        def do_GET(self):
            if self.path == '/' or self.path == '':
                graph_data = build_graph(org_dir, **build_args)
                template = template_path.read_text(encoding='utf-8')
                json_blob = json.dumps(graph_data, ensure_ascii=False)
                html = template.replace('const GRAPH_DATA = null;',
                                        f'const GRAPH_DATA = {json_blob};', 1)
                self._send_html(html)

            elif self.path == '/api/health':
                self._send_json({'ok': True})

            elif self.path.startswith('/api/raw/'):
                file_id, filepath = self._resolve_id('/api/raw/')
                if not file_id or not filepath.exists():
                    self._send_json({'error': 'not found'}, 404)
                    return
                raw = filepath.read_text(encoding='utf-8', errors='replace')
                self._send_text(raw)

            else:
                # Serve static files (images, etc.) from org_dir
                file_path = unquote(self.path.lstrip('/'))
                resolved = (org_dir / file_path).resolve()
                org_root = str(org_dir.resolve())
                if (str(resolved).startswith(org_root + os.sep) and resolved.is_file()):
                    import mimetypes
                    ctype, _ = mimetypes.guess_type(str(resolved))
                    if ctype and ctype.startswith(('image/', 'video/', 'audio/', 'text/html', 'text/javascript', 'application/javascript')):
                        data = resolved.read_bytes()
                        self.send_response(200)
                        self.send_header('Content-Type', ctype)
                        self.send_header('Content-Length', str(len(data)))
                        self._cors_headers()
                        self.end_headers()
                        self.wfile.write(data)
                        return
                self._send_json({'error': 'not found'}, 404)

        def do_POST(self):
            if self.path.startswith('/api/save/'):
                file_id, filepath = self._resolve_id('/api/save/')
                if not file_id:
                    self._send_json({'error': 'invalid path'}, 400)
                    return
                length = int(self.headers.get('Content-Length', 0))
                body = self.rfile.read(length).decode('utf-8')
                # Skip write if content unchanged
                if filepath.exists():
                    existing = filepath.read_text(encoding='utf-8', errors='replace')
                    if existing == body:
                        node = parse_org_file(filepath, org_dir)
                        if node:
                            self._send_json(node)
                        else:
                            self._send_json({'error': 'parse failed'}, 500)
                        return
                filepath.parent.mkdir(parents=True, exist_ok=True)
                filepath.write_text(body, encoding='utf-8')
                # Re-parse the single file
                node = parse_org_file(filepath, org_dir)
                _save_mtime_cache()
                if node:
                    self._send_json(node)
                else:
                    self._send_json({'error': 'parse failed'}, 500)
            elif self.path.startswith('/api/open-emacs/'):
                file_id, filepath = self._resolve_id('/api/open-emacs/')
                if not file_id or not filepath.exists():
                    self._send_json({'error': 'not found'}, 404)
                    return
                try:
                    subprocess.Popen(['alacritty', '--class', 'org-zettel-edit',
                                       '-e', 'emacsclient', '-t', '-a', '', str(filepath)])
                    self._send_json({'ok': True})
                except FileNotFoundError:
                    self._send_json({'error': 'emacsclient not found'}, 500)
            elif self.path.startswith('/api/rename/'):
                file_id, filepath = self._resolve_id('/api/rename/')
                if not file_id:
                    self._send_json({'error': 'invalid path'}, 400)
                    return
                if not filepath.exists():
                    self._send_json({'error': 'not found'}, 404)
                    return
                if not _in_sync_scope(file_id):
                    self._send_json({'error': 'date-named files cannot be renamed'}, 400)
                    return
                # Parse JSON body
                length = int(self.headers.get('Content-Length', 0))
                try:
                    body = json.loads(self.rfile.read(length).decode('utf-8'))
                except (json.JSONDecodeError, UnicodeDecodeError):
                    self._send_json({'error': 'invalid JSON body'}, 400)
                    return
                new_title = body.get('new_title', '').strip()
                if not new_title:
                    self._send_json({'error': 'new_title is required'}, 400)
                    return
                old_base = filepath.stem
                new_base = _title_to_filename(new_title)
                if old_base == new_base:
                    self._send_json({'renamed': False, 'new_id': file_id})
                    return
                new_path = filepath.parent / (new_base + '.org')
                org_root = str(org_dir.resolve())
                if not str(new_path.resolve()).startswith(org_root + os.sep):
                    self._send_json({'error': 'invalid title'}, 400)
                    return
                if new_path.exists():
                    self._send_json({'error': 'target file already exists'}, 409)
                    return
                # Derive old title from filename (not #+TITLE, which may
                # have been auto-saved with the new title already)
                old_title = old_base.replace('_', ' ')
                text = filepath.read_text(encoding='utf-8', errors='replace')
                # Update #+TITLE in the file
                text = re.sub(
                    r'^#\+TITLE:\s*.+',
                    f'#+TITLE: {new_title}',
                    text,
                    count=1,
                    flags=re.IGNORECASE | re.MULTILINE,
                )
                filepath.write_text(text, encoding='utf-8')
                # Rename file
                filepath.rename(new_path)
                # Update backlinks in other files
                updated_files = _update_backlinks(org_dir, old_base, new_base, old_title, new_title)
                # Parse renamed file
                node = parse_org_file(new_path, org_dir)
                _save_mtime_cache()
                new_id = new_path.relative_to(org_dir).as_posix()
                result = {
                    'renamed': True,
                    'old_id': file_id,
                    'new_id': new_id,
                    'updated_files': updated_files,
                }
                if node:
                    result.update(node)
                self._send_json(result)

            else:
                self._send_json({'error': 'not found'}, 404)

        def do_OPTIONS(self):
            self.send_response(204)
            self._cors_headers()
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')
            self.end_headers()

    return Handler


def main():
    parser = argparse.ArgumentParser(description="Build org-mode zettelkasten viewer")
    daily_group = parser.add_mutually_exclusive_group()
    daily_group.add_argument("--exclude-daily", action="store_true", default=True,
                             help="Exclude daily notes (default)")
    daily_group.add_argument("--include-daily", action="store_true",
                             help="Include daily notes")

    orphan_group = parser.add_mutually_exclusive_group()
    orphan_group.add_argument("--exclude-orphans", action="store_true", default=True,
                              help="Exclude orphan nodes (default)")
    orphan_group.add_argument("--include-orphans", action="store_true",
                              help="Include orphan nodes")

    parser.add_argument("--min-backlinks", type=int, default=0,
                        help="Only show nodes with at least N backlinks")
    parser.add_argument("--serve", action="store_true",
                        help="Start a live HTTP server instead of static export")
    parser.add_argument("--port", type=int, default=8080,
                        help="Port for the HTTP server (default: 8080)")

    args = parser.parse_args()

    if args.serve:
        build_args = {
            'include_daily': args.include_daily,
            'include_orphans': args.include_orphans,
            'min_backlinks': args.min_backlinks,
        }
        handler = make_handler(ORG_DIR, TEMPLATE, build_args)
        server = HTTPServer(('127.0.0.1', args.port), handler)
        print(f"Serving on http://127.0.0.1:{args.port}", file=sys.stderr)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.", file=sys.stderr)
        return

    graph_data = build_graph(
        ORG_DIR,
        include_daily=args.include_daily,
        include_orphans=args.include_orphans,
        min_backlinks=args.min_backlinks,
    )

    # Read template and inject data
    if not TEMPLATE.exists():
        print(f"Error: template not found at {TEMPLATE}", file=sys.stderr)
        sys.exit(1)

    template = TEMPLATE.read_text(encoding="utf-8")
    json_blob = json.dumps(graph_data, ensure_ascii=False)
    output = template.replace("const GRAPH_DATA = null;",
                               f"const GRAPH_DATA = {json_blob};", 1)

    OUTPUT.write_text(output, encoding="utf-8")
    print(f"Wrote {OUTPUT}", file=sys.stderr)


if __name__ == "__main__":
    main()
