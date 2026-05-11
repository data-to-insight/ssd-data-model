#!/usr/bin/env python3
from pathlib import Path
import argparse


DEFAULT_GLOB = "deployment_extracts/eclipse/live/ssd_deployment_individual_files_tsql/*.sql"

# search-replace values
OLD = "[eclipseDelta].[dbo].[ssd_"
OLD = "[SSD].[ssd_"
NEW = "[ssd_"


def replace_in_file(path: Path, dry_run: bool = False) -> tuple[bool, int]:
    text = path.read_text(encoding="utf-8")
    count = text.count(OLD)

    if count == 0:
        return False, 0

    updated = text.replace(OLD, NEW)

    if not dry_run:
        path.write_text(updated, encoding="utf-8", newline="")

    return True, count


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Replace eclipseDelta dbo SSD table references with SSD schema references."
    )
    parser.add_argument(
        "--glob",
        default=DEFAULT_GLOB,
        help=f"Glob pattern to search. Default: {DEFAULT_GLOB}",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would change without editing files.",
    )

    args = parser.parse_args()

    files = sorted(Path(".").glob(args.glob))

    if not files:
        print(f"No files found for pattern: {args.glob}")
        return

    changed_files = 0
    total_replacements = 0

    for path in files:
        changed, count = replace_in_file(path, dry_run=args.dry_run)

        if changed:
            changed_files += 1
            total_replacements += count
            action = "Would update" if args.dry_run else "Updated"
            print(f"{action}: {path} ({count} replacement{'s' if count != 1 else ''})")

    print()
    print(f"Files scanned: {len(files)}")
    print(f"Files changed: {changed_files}")
    print(f"Total replacements: {total_replacements}")

    if args.dry_run:
        print("Dry run only, no files were modified.")


if __name__ == "__main__":
    main()