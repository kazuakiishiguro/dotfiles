#!/usr/bin/env python3
"""Scan ~/org/ .org files and produce a self-contained graph visualization.

Usage:
    cd ~/org && python3 org-graph.py && xdg-open org-graph-view.html

Or add a shell alias:
    alias org-graph='cd ~/org && python3 org-graph.py && xdg-open org-graph-view.html'

Flags:
    --include-daily      Include daily notes (excluded by default)
    --include-orphans    Include unlinked nodes (excluded by default)
    --min-backlinks N    Only show nodes with >= N backlinks
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()
ORG_DIR = Path.cwd()
TEMPLATE = SCRIPT_DIR / "org-graph.html"
OUTPUT = ORG_DIR / "org-graph-view.html"

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

    return {
        "id": rel,
        "title": title or Path(rel).stem.replace("-", " ").replace("_", " "),
        "date": date,
        "tags": tags,
        "category": classify(rel),
        "backlinks": backlink_count,
        "links": links,
        "content": "\n".join(body_lines),
    }


def build_graph(org_dir: Path, include_daily: bool, include_orphans: bool, min_backlinks: int):
    """Scan all .org files and build the graph data structure."""
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
        })

    print(f"Nodes: {len(out_nodes)}  Edges: {len(edges)}  Tags: {len(all_tags)}", file=sys.stderr)

    return {
        "nodes": out_nodes,
        "edges": edges,
        "categories": categories,
        "tags": all_tags,
    }


def main():
    parser = argparse.ArgumentParser(description="Build org-mode graph visualization")
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

    args = parser.parse_args()

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
