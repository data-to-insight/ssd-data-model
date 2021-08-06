from dataclasses import asdict

import yaml

from rtofdata.config import jekyll_dir
from rtofdata.spec_parser import Specification


def write_jekyll_specification(spec: Specification):
    write_records(spec)


def write_records(spec: Specification):

    for r in spec.records:
        with open(jekyll_dir / f"collections/_records/{r.id}.md", "wt") as file:
            print("---", file=file)
            yaml.dump(dict(record=asdict(r), layout="record"), file)
            print("---", file=file)

    with open(jekyll_dir / f"collections/_records/index.md", "wt") as file:
        records = [f.record for f in spec.records_by_flow]

        print("""---
layout: default
---        
        """, file=file)
        for r in records:
            print(f" * [{r.id}]({r.id}.html)", file=file)

