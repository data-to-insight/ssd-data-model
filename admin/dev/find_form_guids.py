#!/usr/bin/env python3

"""
find_form_guids.py

Scan Eclipse deployment SQL scripts for FAPV.CONTROLNAME IN (...) and
FAPV.DESIGNGUID IN (...), and write a CSV listing each distinct value found
per script, ready for downstream replacement mapping.

Expected location of this script:
    /workspaces/ssd-data-model/admin/dev/find_form_guids.py

Scanned SQL directory:
    /workspaces/ssd-data-model/deployment_extracts/eclipse/live/ssd_deployment_individual_files/

Output CSV:
    /workspaces/ssd-data-model/admin/dev/form_guids_scan.csv
"""

import csv
import re
from pathlib import Path


def find_repo_root() -> Path:
    """
    Starting from this script, walk up to the ssd-data-model root.
    Assumes this file lives in admin/dev/ under the repo root.
    """
    script_path = Path(__file__).resolve()
    # ... /ssd-data-model/admin/dev/find_form_guids.py
    # parents[0] = dev, [1] = admin, [2] = ssd-data-model
    try:
        return script_path.parents[2]
    except IndexError:
        raise SystemExit("Could not locate repo root from script location")


def extract_values(sql_text: str) -> set[str]:
    """
    Given full SQL text, find all values inside
      FAPV.CONTROLNAME IN ('...') and
      FAPV.DESIGNGUID IN ('...')
    and return a set of the extracted string values.

    Handles multiple values in a single IN list, for example:
        FAPV.CONTROLNAME IN ('A', 'B', 'C')
    """
    control_pattern = re.compile(
        r"FAPV\.CONTROLNAME\s+IN\s*\(([^)]*)\)",
        re.IGNORECASE | re.DOTALL,
    )
    guid_pattern = re.compile(
        r"FAPV\.DESIGNGUID\s+IN\s*\(([^)]*)\)",
        re.IGNORECASE | re.DOTALL,
    )
    value_pattern = re.compile(r"'([^']*)'")

    found_values: set[str] = set()

    # Helper to process a given IN pattern
    def _collect(pattern: re.Pattern) -> None:
        for match in pattern.finditer(sql_text):
            inside = match.group(1)
            for val in value_pattern.findall(inside):
                val = val.strip()
                if val:
                    found_values.add(val)

    _collect(control_pattern)
    _collect(guid_pattern)

    return found_values


def main() -> None:
    repo_root = find_repo_root()

    sql_dir = (
        repo_root
        / "deployment_extracts"
        / "eclipse"
        / "live"
        / "ssd_deployment_individual_files"
    )

    if not sql_dir.is_dir():
        raise SystemExit(f"SQL directory not found: {sql_dir}")

    output_csv = Path(__file__).resolve().parent / "form_guids_scan.csv"

    rows: list[tuple[str, str, str]] = []

    for sql_path in sorted(sql_dir.glob("*.sql")):
        try:
            text = sql_path.read_text(encoding="utf-8", errors="ignore")
        except Exception as exc:
            print(f"Warning: could not read {sql_path}: {exc}")
            continue

        values = extract_values(text)
        if not values:
            continue

        script_name = sql_path.name
        for val in sorted(values):
            # Columns: script_name, found_value, replacement_name (blank)
            rows.append((script_name, val, ""))

    # Write CSV
    with output_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["script_name", "found_value", "replacement_name"])
        writer.writerows(rows)

    print(f"Wrote {len(rows)} rows to {output_csv}")


if __name__ == "__main__":
    main()
