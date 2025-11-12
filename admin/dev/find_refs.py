#!/usr/bin/env python3
# chmod +x find_refs.py
"""
Search recursively for all refs to variable name in files. Use this if considering/making a var name change to
ensure that all instances are known and can better assess impact/overheads etc.

Default variable searched: 'pers_common_child_id'

Usage examples
  ./find_refs.py                     # search current directory (can also use for all if running from root)
  ./find_refs.py /path/to/repo       # search specific repo
  ./find_refs.py -p other_var src/   # search for a different variable name
"""

import argparse
import os
from pathlib import Path

DEFAULT_SKIP_DIRS = {
    ".git", ".hg", ".svn", ".idea", ".vscode", "__pycache__", ".mypy_cache",
    "node_modules", "dist", "build", "out", ".venv", "venv", "env", "deployment_extracts_la_release", "admin", "data", "la_config_files"
}

def should_skip_dir(dirname: str) -> bool:
    return dirname in DEFAULT_SKIP_DIRS

def search_file(file_path: Path, needle: str) -> list[tuple[int, str]]:
    hits = []
    try:
        with file_path.open("r", encoding="utf-8", errors="ignore") as f:
            for i, line in enumerate(f, start=1):
                if needle in line:
                    hits.append((i, line.rstrip("\n")))
    except Exception:
        # silent skip unreadable files
        pass
    return hits

def main():
    parser = argparse.ArgumentParser(description="Recursive variable reference search")
    parser.add_argument("root", nargs="?", default=".", help="Root folder to search")
    parser.add_argument("-p", "--pattern", default="pers_common_child_id",
                        help="Variable or text to find")
    parser.add_argument("--max-bytes", type=int, default=25_000_000,
                        help="Skip files larger than this many bytes")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    needle = args.pattern

    if not root.exists():
        print(f"Path not found: {root}")
        raise SystemExit(1)

    total_hits = 0
    for dirpath, dirnames, filenames in os.walk(root):
        # prune directories in place for speed
        dirnames[:] = [d for d in dirnames if not should_skip_dir(d)]

        for name in filenames:
            file_path = Path(dirpath) / name
            try:
                if file_path.stat().st_size > args.max_bytes:
                    continue
            except OSError:
                continue

            hits = search_file(file_path, needle)
            if hits:
                for line_no, text in hits:
                    # grep-like output: path:line: text
                    print(f"{file_path}:{line_no}: {text}")
                    total_hits += 1

    if total_hits == 0:
        print(f"No matches for '{needle}' under {root}")

if __name__ == "__main__":
    main()
