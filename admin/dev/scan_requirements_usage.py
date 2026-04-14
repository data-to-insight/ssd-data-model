from __future__ import annotations

import ast
import json
import re
import sys
from pathlib import Path
from typing import Iterable

try:
    from importlib.metadata import packages_distributions
except ImportError:
    # Python < 3.10 fallback
    from importlib_metadata import packages_distributions  # type: ignore


ROOT = Path(".")
SKIP_DIRS = {
    ".git",
    ".venv",
    "venv",
    "__pycache__",
    ".mypy_cache",
    ".pytest_cache",
    ".ipynb_checkpoints",
    "node_modules",
    "dist",
    "build",
}


def normalise_name(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower().strip()


def parse_requirement_name(line: str) -> str | None:
    line = line.strip()
    if not line or line.startswith("#"):
        return None

    # remove inline comments
    if " #" in line:
        line = line.split(" #", 1)[0].strip()

    # ignore pip options and includes
    if line.startswith(("-", "--")):
        return None

    # remove markers
    if ";" in line:
        line = line.split(";", 1)[0].strip()

    # editable installs or VCS/URL refs skipped here
    if line.startswith(("git+", "http://", "https://", "file:")):
        return None

    # handle package[extra]==1.2.3 etc
    match = re.match(r"^\s*([A-Za-z0-9_.-]+)", line)
    if not match:
        return None

    return normalise_name(match.group(1))


def load_requirements(path: Path) -> set[str]:
    reqs: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        name = parse_requirement_name(line)
        if name:
            reqs.add(name)
    return reqs


def iter_python_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.is_file() and path.suffix in {".py", ".ipynb"}:
            yield path


def extract_imports_from_python(source: str, filename: str = "<string>") -> set[str]:
    imports: set[str] = set()
    try:
        tree = ast.parse(source, filename=filename)
    except SyntaxError:
        return imports

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                top = alias.name.split(".", 1)[0]
                if top:
                    imports.add(top)
        elif isinstance(node, ast.ImportFrom):
            if node.module:
                top = node.module.split(".", 1)[0]
                if top:
                    imports.add(top)

    return imports


def extract_imports_from_notebook(path: Path) -> set[str]:
    imports: set[str] = set()
    try:
        nb = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return imports

    for cell in nb.get("cells", []):
        if cell.get("cell_type") != "code":
            continue
        source = "".join(cell.get("source", []))
        imports |= extract_imports_from_python(source, filename=str(path))

    return imports


def extract_all_imports(root: Path) -> set[str]:
    imports: set[str] = set()

    for path in iter_python_files(root):
        try:
            if path.suffix == ".py":
                source = path.read_text(encoding="utf-8")
                imports |= extract_imports_from_python(source, filename=str(path))
            elif path.suffix == ".ipynb":
                imports |= extract_imports_from_notebook(path)
        except Exception:
            continue

    return imports


def get_stdlib_modules() -> set[str]:
    stdlib = set(getattr(sys, "stdlib_module_names", set()))
    # common aliases / historically awkward cases
    stdlib |= {
        "typing",
        "pathlib",
        "json",
        "re",
        "math",
        "datetime",
        "collections",
        "itertools",
        "functools",
        "subprocess",
        "unittest",
        "logging",
        "argparse",
        "csv",
        "os",
        "sys",
        "ast",
    }
    return stdlib


def main() -> int:
    req_path = ROOT / "requirements.txt"
    if not req_path.exists():
        print("requirements.txt not found in current directory")
        return 1

    requirements = load_requirements(req_path)
    raw_imports = extract_all_imports(ROOT)
    stdlib = get_stdlib_modules()

    imports = {i for i in raw_imports if i not in stdlib and i != "__future__"}

    mapping = packages_distributions()

    used_requirements: set[str] = set()
    unresolved_imports: set[str] = set()

    for module in sorted(imports):
        dists = mapping.get(module, [])
        if not dists:
            unresolved_imports.add(module)
            continue
        for dist in dists:
            used_requirements.add(normalise_name(dist))

    declared_but_not_seen = sorted(requirements - used_requirements)
    seen_but_not_declared = sorted(used_requirements - requirements)

    print("\n=== Imported top-level modules found in code ===")
    for mod in sorted(imports):
        print(mod)

    print("\n=== Requirements that look used by imports ===")
    for req in sorted(requirements & used_requirements):
        print(req)

    print("\n=== Requirements declared but not obviously used ===")
    for req in declared_but_not_seen:
        print(req)

    print("\n=== Imported packages seen in environment but not declared in requirements ===")
    for req in seen_but_not_declared:
        print(req)

    print("\n=== Imports that could not be mapped to an installed distribution ===")
    for mod in sorted(unresolved_imports):
        print(mod)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())