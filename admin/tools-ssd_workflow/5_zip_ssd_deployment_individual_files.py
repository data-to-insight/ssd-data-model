#!/usr/bin/env python3

# chmod +x 5_zip_ssd_deployment_individual_files.py

# Check release details in deployment_extracts/ssd_version_history.yml has been updated before running this
# as resultant file names and versioning are pulled from this file and prefixed/suffixed to output .zip release files

import zipfile
from pathlib import Path
from typing import Tuple

import yaml


def find_deployment_extracts_root() -> Path:
    """
    Walk up from this script until finding 'deployment_extracts/' folder.
    """
    script_path = Path(__file__).resolve()

    for parent in script_path.parents:
        candidate = parent / "deployment_extracts"
        if candidate.is_dir():
            return candidate

    raise SystemExit(
        "Couldn't find 'deployment_extracts' folder by walking up from script location"
    )


def load_current_version_info(deployment_extracts_root: Path) -> Tuple[str, str]:
    """
    Load current SSD version and release date from YAML

    Expects file:
        deployment_extracts/ssd_version_history.yml

    And structure like:
        current_version: "1.3.7"
        releases:
          - version_number: "1.3.7"
            release_date: "2025-12-03"
            ...

    Returns:
        (version_number, release_date_str)
    """
    version_file = deployment_extracts_root / "ssd_version_history.yml"

    if not version_file.is_file():
        raise SystemExit(
            f"Version history file not found at {version_file}. "
            "Ensure ssd_version_history.yml exists in deployment_extracts/"
        )

    try:
        data = yaml.safe_load(version_file.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"Failed to parse {version_file}: {exc}") from exc

    if not isinstance(data, dict):
        raise SystemExit(f"Unexpected YAML structure in {version_file}, expected a mapping at root level")

    current_version = data.get("current_version")
    if not current_version:
        raise SystemExit(f"'current_version' key missing or empty in {version_file}")

    releases = data.get("releases") or []
    if not isinstance(releases, list):
        raise SystemExit(f"'releases' key in {version_file} is not a list")

    matched = None
    for rel in releases:
        if not isinstance(rel, dict):
            continue
        if str(rel.get("version_number")) == str(current_version):
            matched = rel
            break

    if matched is None:
        raise SystemExit(
            f"No release entry found in {version_file} with version_number == {current_version}"
        )

    release_date = matched.get("release_date")
    if not release_date:
        raise SystemExit(
            f"Release entry for version {current_version} in {version_file} is missing 'release_date'"
        )

    return str(current_version), str(release_date)


def build_vendor_bundle(
    vendor_dir: Path,
    release_date_str: str,
    version_number: str,
    deployment_extracts_root: Path,
) -> None:
    """
    Build zip bundle for each single CMS folder, for example:
      deployment_extracts/mosaic/live
      deployment_extracts/eclipse/live

    Assumptions:
      - SQL files to zip:
            deployment_extracts/<vendor>/live/ssd_deployment_individual_files/*.sql
        fallback:
            deployment_extracts/<vendor>/live/*.sql

    Output (per vendor):
      <release_date>-ssd_<vendor>_deployment_v<version>.zip
      for example:
      2025-12-03-ssd_mosaic_deployment_v1.3.7.zip

      and if found:
      <release_date>-ssd_<vendor>_deployment_proc_v<version>.zip
      for example:
      2025-12-03-ssd_systemc_deployment_proc_v1.3.7.zip

    Also injects into each bundle (if present):
      deployment_extracts/ssd_version_history.yml  -> ssd_version_history.yml
      deployment_extracts/ssd_README.md            -> ssd_README.md
    """
    vendor_name = vendor_dir.name  # mosaic, eclipse, etc.
    live_dir = vendor_dir / "live"

    if not live_dir.is_dir():
        print(f"Skipping {vendor_name} (no live directory at {live_dir})")
        return

    # Preferred input root is ssd_deployment_individual_files/
    input_root = live_dir / "ssd_deployment_individual_files"
    if not input_root.is_dir():
        input_root = live_dir

    # All CMS type folders: only zip *.sql files
    candidates = list(input_root.rglob("*.sql"))

    files_to_zip = [p for p in candidates if p.is_file()]

    if not files_to_zip:
        print(f"Skipping {vendor_name} (no .sql files to zip in {input_root})")
        return

    # Shared extra files, taken once from deployment_extracts root
    version_file = deployment_extracts_root / "ssd_version_history.yml"
    readme_file = deployment_extracts_root / "ssd_README.md"
    extra_files = []
    if version_file.is_file():
        extra_files.append((version_file, "ssd_version_history.yml"))
    else:
        print(f"Warning: {version_file} not found, will not be included in bundles")
    if readme_file.is_file():
        extra_files.append((readme_file, "ssd_README.md"))
    else:
        print(f"Warning: {readme_file} not found, will not be included in bundles")

    # Main bundle, for example:
    # 2025-12-03-ssd_mosaic_deployment_v1.3.7.zip
    zip_name = f"{release_date_str}-ssd_{vendor_name}_deployment_v{version_number}.zip"
    zip_path = live_dir / zip_name

    with zipfile.ZipFile(zip_path, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
        # Vendor specific SQL files
        for file_path in files_to_zip:
            arcname = file_path.relative_to(live_dir)
            zf.write(file_path, arcname)

        # Common files at top level of the zip
        for extra_path, arcname in extra_files:
            zf.write(extra_path, arcname)

    print(f"Created zip for {vendor_name}: {zip_path}")

    # Optional second bundle: ssd_deployment_proc_files/
    proc_root = live_dir / "ssd_deployment_proc_files"
    if proc_root.is_dir():
        proc_candidates = list(proc_root.rglob("*.sql"))
        proc_files_to_zip = [p for p in proc_candidates if p.is_file()]

        if proc_files_to_zip:
            # For example:
            # 2025-12-03-ssd_systemc_deployment_proc_v1.3.7.zip
            proc_zip_name = f"{release_date_str}-ssd_{vendor_name}_deployment_proc_v{version_number}.zip"
            proc_zip_path = live_dir / proc_zip_name

            with zipfile.ZipFile(proc_zip_path, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
                for file_path in proc_files_to_zip:
                    arcname = file_path.relative_to(live_dir)
                    zf.write(file_path, arcname)

                # Common files again at top level
                for extra_path, arcname in extra_files:
                    zf.write(extra_path, arcname)

            print(f"Created proc zip for {vendor_name}: {proc_zip_path}")
        else:
            print(f"Skipping {vendor_name} proc bundle (no .sql files to zip in {proc_root})")
    else:
        print(f"Skipping {vendor_name} proc bundle (no ssd_deployment_proc_files/ at {proc_root})")


def main() -> None:
    deployment_extracts_root = find_deployment_extracts_root()
    version_number, release_date_str = load_current_version_info(deployment_extracts_root)

    print(
        f"Using SSD version {version_number} with release date {release_date_str} "
        f"from ssd_version_history.yml"
    )

    any_built = False

    # Iterate CMS folders, for example mosaic, eclipse
    for vendor_dir in sorted(deployment_extracts_root.iterdir()):
        if not vendor_dir.is_dir():
            continue
        build_vendor_bundle(vendor_dir, release_date_str, version_number, deployment_extracts_root)
        any_built = True

    if not any_built:
        raise SystemExit("No deployment bundles created. Check folders and contents under deployment_extracts/")


if __name__ == "__main__":
    main()
