# chmod +x zip_ssd_mosaic_deployment.py
#!/usr/bin/env python3


# cd /workspaces/ssd-data-model/admin/tools-ssd_workflow/admin/
# python zip_ssd_mosaic_deployment.py
# # or after chmod:
# ./zip_ssd_mosaic_deployment.py



import zipfile
from pathlib import Path
from datetime import date


def main() -> None:
    # Fixed path inside the Codespace workspace
    live_dir = Path("/workspaces/ssd-data-model/deployment_extracts/mosaic/live/").resolve()
    live_input_dir = live_dir+"ssd_mosaic_deployment_individual_files/"
    if not live_input_dir.is_dir():
        raise SystemExit(f"Live directory not found: {live_input_dir}")

    # Filename like 2025-11-18-ssd_mosaic_deployment_download.zip
    today_str = date.today().strftime("%Y-%m-%d")
    zip_name = f"{today_str}-ssd_mosaic_deployment_download.zip"
    zip_path = live_dir / zip_name

    # Collect files to zip, skipping any existing deployment zip bundles
    files_to_zip = []
    for path in live_input_dir.rglob("*"):
        if path.is_file():
            # Avoid including current or earlier deployment bundles
            if path.name.endswith("ssd_mosaic_deployment_download.zip"):
                continue
            files_to_zip.append(path)

    if not files_to_zip:
        raise SystemExit(f"No files to zip in {live_input_dir}")

    # mode="w" will create or replace the zip file
    with zipfile.ZipFile(zip_path, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
        for file_path in files_to_zip:
            # Store paths relative to the live directory
            arcname = file_path.relative_to(live_dir)
            zf.write(file_path, arcname)

    print(f"Created zip: {zip_path}")


if __name__ == "__main__":
    main()
