import shutil
from dataclasses import asdict

import yaml

from rtofdata.config import jekyll_dir, output_dir
from rtofdata.spec_parser import Specification


def write_jekyll_specification(spec: Specification):
    write_records(spec)
    write_dimensions(spec)
    copy_assets()


def copy_assets():
    assets_dir = jekyll_dir / "assets/spec/"
    try:
        shutil.rmtree(assets_dir)
    except FileNotFoundError:
        pass

    shutil.copytree(output_dir, assets_dir)
    (assets_dir / ".gitignore").unlink(missing_ok=True)


def write_records(spec: Specification):
    dir = jekyll_dir / "collections/_records/"
    dir.mkdir(parents=True, exist_ok=True)

    for r in spec.records:
        with open(dir / f"{r.id}.md", "wt") as file:
            print("---", file=file)
            yaml.dump(dict(record=asdict(r), layout="record"), file)
            print("---", file=file)

    with open(dir / "index.md", "wt") as file:
        records = [f.record for f in spec.records_by_flow]

        print("""---
layout: default
---        
        """, file=file)
        for r in records:
            print(f" * [{r.id}]({r.id}.html)", file=file)

        print("""

![Entity Relationship Diagram][erd]


[erd]: {% link /assets/spec/record-relationships.png %}         
        """, file=file)


def write_dimensions(spec: Specification):
    dir = jekyll_dir / "collections/_dimensions/"
    dir.mkdir(parents=True, exist_ok=True)

    for d in spec.dimensions:
        with open(dir / f"{d.id}.md", "wt") as file:
            print("---", file=file)
            yaml.dump(dict(dimensions=asdict(d), layout="dimension"), file)
            print("---", file=file)

    dims = [d for d in spec.dimensions]
    dims.sort(key=lambda d: d.id)
    with open(dir / "index.md", "wt") as file:
        print("""---
layout: default
---        
        """, file=file)
        for d in dims:
            print(f" * [{d.id}]({d.id}.html)", file=file)