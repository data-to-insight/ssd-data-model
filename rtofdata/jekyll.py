import shutil
from dataclasses import asdict
import xml.etree.ElementTree as ET

import yaml

from rtofdata.config import jekyll_dir, output_dir
from rtofdata.spec_parser import Specification

assets_dir = jekyll_dir / "assets/spec/"


def write_jekyll_specification(spec: Specification):
    write_records(spec)
    write_dimensions(spec)
    copy_assets()
    add_links_to_chart()


def add_links_to_chart():
    namespaces = {'svg': 'http://www.w3.org/2000/svg'}
    ET.register_namespace('', 'http://www.w3.org/2000/svg')

    tree = ET.parse(assets_dir / 'record-relationships.svg')
    root = tree.getroot()
    root.attrib['width'] = "auto"
    root.attrib['height'] = "auto"

    root_graph = root.find('svg:g', namespaces)
    background = root_graph.find('svg:polygon', namespaces)
    root_graph.remove(background)

    sub_graphs = root_graph.findall('svg:g', namespaces)
    for sg in sub_graphs:
        root_graph.remove(sg)

        link = ET.Element("a")
        link.attrib['href'] = f"./{sg.attrib['id']}.html"
        root_graph.append(link)
        link.append(sg)

    (jekyll_dir / '_includes').mkdir(parents=True, exist_ok=True)
    with open(jekyll_dir / '_includes/record-relationships.svg', 'wb') as f:
        tree.write(f, encoding='utf-8')


def copy_assets():
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

{% include record-relationships.svg %}
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