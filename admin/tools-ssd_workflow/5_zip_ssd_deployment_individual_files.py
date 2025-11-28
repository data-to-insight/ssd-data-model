# chmod +x zip_ssd_deployment_individual_files.py
#!/usr/bin/env python3

# cd /workspaces/ssd-data-model/admin/tools-ssd_workflow/admin/
# python zip_ssd_deployment_individual_files.py


import zipfile
from pathlib import Path
from datetime import date


def find_deployment_extracts_root() -> Path:
    """
    Walk up from this script until finding 'deployment_extracts' folder
    """
    script_path = Path(__file__).resolve()

    for parent in script_path.parents:
        candidate = parent / "deployment_extracts"
        if candidate.is_dir():
            return candidate

    raise SystemExit(
        "Couldn't find 'deployment_extracts' folder by walking up from script location"
    )


def build_vendor_bundle(vendor_dir: Path, today_str: str) -> None:
    """
    Build zip bundle for each single vendor folder, e..g:
      deployment_extracts/mosaic/live
      deployment_extracts/eclipse/live

    Assumptions:
      - SQL files to zip in:
            deployment_extracts/<vendor>/live/ssd_deployment_individual_files/*.sql
        fallback to:
            deployment_extracts/<vendor>/live/*.sql
    """
    vendor_name = vendor_dir.name  # mosaic, eclipse, etc.
    live_dir = vendor_dir / "live"

    if not live_dir.is_dir():
        print(f"Skipping {vendor_name} (no live directory at {live_dir})")
        return

    # Init input root is ssd_deployment_individual_files
    input_root = live_dir / "ssd_deployment_individual_files"
    if not input_root.is_dir():
        input_root = live_dir

    # All CMS type folders: only zip *.sql files
    candidates = list(input_root.rglob("*.sql"))

    files_to_zip = []
    for path in candidates:
        # Avoid including current or previous deployment bundles
        if path.name.endswith(f"ssd_{vendor_name}_deployment_download.zip"):
            continue
        files_to_zip.append(path)

    if not files_to_zip:
        print(f"Skipping {vendor_name} (no .sql files to zip in {input_root})")
        return

    # Eg: 2025-11-25-ssd_mosaic_deployment_download.zip
    zip_name = f"{today_str}-ssd_{vendor_name}_deployment_download.zip"
    zip_path = live_dir / zip_name

    with zipfile.ZipFile(zip_path, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
        for file_path in files_to_zip:
            # Store paths relative to live directory
            arcname = file_path.relative_to(live_dir)
            zf.write(file_path, arcname)

    print(f"Created zip for {vendor_name}: {zip_path}")


def main() -> None:
    deployment_extracts_root = find_deployment_extracts_root()
    today_str = date.today().strftime("%Y-%m-%d")

    any_built = False

    # Iterate CMS folders, mosaic, eclipse
    for vendor_dir in sorted(deployment_extracts_root.iterdir()):
        if not vendor_dir.is_dir():
            continue
        build_vendor_bundle(vendor_dir, today_str)
        any_built = True

    if not any_built:
        raise SystemExit("No deployment bundles created. Check folders and contents")


if __name__ == "__main__":
    main()
