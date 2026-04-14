#!/usr/bin/env python3
"""
Extract SSD table/column metadata from SQL DDL files

does
------------
- Scans one or more glob patterns for .sql files
- Finds CREATE TABLE blocks
- Keeps only tables whose base table name starts with a chosen prefix, default: ssd_
- Normalises temp table names like #ssd_person and ##ssd_person to ssd_person
- Extracts one row per column with source system, schema, table, column, datatype, size, nullability, and source file
- Writes per-source CSVs plus a combined CSV and a simple table summary CSV

produces normalised ref that is easy to compare e.g:
- same number of fields per table?
- same field names?
- same datatype and size for same-named fields?

use
-------------
python extract_ssd_ddl_reference.py

python extract_ssd_ddl_reference.py \
  --output-dir ./analysis/ddl_reference \
  --prefix ssd_
"""

from __future__ import annotations

import argparse
import csv
import glob
import json
import re
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterator, Optional, Sequence, Tuple

import pandas as pd


DEFAULT_SOURCE_PATTERNS = {
    "mosaic": [
        "./deployment_extracts/mosaic/live/ssd_deployment_individual_files/*.sql",
        "./deployment_extracts/mosaic/live/**/*.sql",
    ],
    "systemc": [
        "./deployment_extracts/systemc/live/ssd_deployment_individual_files/*.sql",
        "./deployment_extracts/systemc/live/**/*.sql",
    ],
    "eclipse": [
        "./deployment_extracts/eclipse/live/ssd_deployment_individual_files/*.sql",
        "./deployment_extracts/eclipse/live/**/*.sql",
    ],
}

TABLE_LEVEL_PREFIXES = {
    "CONSTRAINT",
    "PRIMARY",
    "FOREIGN",
    "UNIQUE",
    "CHECK",
    "KEY",
    "INDEX",
    "DISTRIBUTION",
    "SORTKEY",
    "DISTKEY",
    "PARTITION",
    "CLUSTERED",
    "NONCLUSTERED",
}

TYPE_STOP_TOKENS = {
    "NOT",
    "NULL",
    "DEFAULT",
    "CONSTRAINT",
    "PRIMARY",
    "REFERENCES",
    "CHECK",
    "COLLATE",
    "UNIQUE",
    "IDENTITY",
    "GENERATED",
    "ENCODE",
    "DISTKEY",
    "SORTKEY",
    "COMMENT",
    "MASKED",
    "SPARSE",
    "PERSISTED",
}

STRING_TYPES = {
    "char",
    "nchar",
    "varchar",
    "nvarchar",
    "binary",
    "varbinary",
    "character varying",
    "character",
    "text",
    "ntext",
}

NUMERIC_TYPES = {
    "decimal",
    "numeric",
    "number",
    "float",
    "real",
    "double precision",
    "money",
    "smallmoney",
}


@dataclass
class ColumnRecord:
    source_system: str
    source_file: str
    schema_name: Optional[str]
    table_name: str
    field_name: str
    table_field: str
    ordinal_position: int
    data_type: str
    size_text: Optional[str]
    full_type: str
    max_length: Optional[str]
    numeric_precision: Optional[str]
    numeric_scale: Optional[str]
    is_nullable: Optional[bool]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract SSD DDL reference from SQL files")
    parser.add_argument(
        "--output-dir",
        default="./analysis/ddl_reference",
        help="Directory to write CSV outputs into",
    )
    parser.add_argument(
        "--prefix",
        default="ssd_",
        help="Only keep tables whose base table name starts with this prefix",
    )
    parser.add_argument(
        "--patterns-json",
        default="",
        help=(
            "Optional JSON string or JSON file path overriding source patterns. "
            "Shape must be {\"mosaic\": [\"glob\", ...], ...}"
        ),
    )
    return parser.parse_args()


def load_source_patterns(patterns_json: str) -> dict[str, list[str]]:
    if not patterns_json:
        return DEFAULT_SOURCE_PATTERNS

    candidate = Path(patterns_json)
    if candidate.exists():
        data = json.loads(candidate.read_text(encoding="utf-8"))
    else:
        data = json.loads(patterns_json)

    out: dict[str, list[str]] = {}
    for source, patterns in data.items():
        if isinstance(patterns, str):
            out[source] = [patterns]
        else:
            out[source] = list(patterns)
    return out


def strip_sql_comments(sql: str) -> str:
    """
    Remove block and line comments.
    This is deliberately pragmatic rather than a full SQL lexer.
    """
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.S)
    sql = re.sub(r"--.*?$", "", sql, flags=re.M)
    return sql


def normalise_identifier(identifier: str) -> str:
    identifier = identifier.strip()
    if identifier.startswith("[") and identifier.endswith("]"):
        return identifier[1:-1]
    if identifier.startswith('"') and identifier.endswith('"'):
        return identifier[1:-1]
    if identifier.startswith("`") and identifier.endswith("`"):
        return identifier[1:-1]
    return identifier


def normalise_table_name_for_match(table_name: Optional[str]) -> Optional[str]:
    """
    Normalise temp-table style names before prefix matching and output.

    Examples:
    - ##ssd_person -> ssd_person
    - #ssd_person  -> ssd_person
    - ssd_person   -> ssd_person
    """
    if table_name is None:
        return None
    return table_name.lstrip("#").strip()


def split_identifier_chain(text: str) -> list[str]:
    parts: list[str] = []
    i = 0
    n = len(text)

    while i < n:
        while i < n and text[i].isspace():
            i += 1
        if i >= n:
            break

        if text[i] == "[":
            j = i + 1
            while j < n and text[j] != "]":
                j += 1
            parts.append(text[i : min(j + 1, n)])
            i = min(j + 1, n)
        elif text[i] in {'"', '`'}:
            quote = text[i]
            j = i + 1
            while j < n and text[j] != quote:
                j += 1
            parts.append(text[i : min(j + 1, n)])
            i = min(j + 1, n)
        else:
            j = i
            while j < n and (text[j].isalnum() or text[j] in {"_", "$", "#"}):
                j += 1
            if j > i:
                parts.append(text[i:j])
                i = j
            else:
                i += 1
                continue

        while i < n and text[i].isspace():
            i += 1
        if i < n and text[i] == ".":
            i += 1

    return [normalise_identifier(p) for p in parts if p.strip()]


def find_matching_paren(text: str, open_pos: int) -> int:
    assert text[open_pos] == "("
    depth = 0
    i = open_pos
    n = len(text)
    in_single_quote = False
    in_double_quote = False
    in_bracket_ident = False

    while i < n:
        ch = text[i]

        if in_single_quote:
            if ch == "'":
                if i + 1 < n and text[i + 1] == "'":
                    i += 2
                    continue
                in_single_quote = False
            i += 1
            continue

        if in_double_quote:
            if ch == '"':
                in_double_quote = False
            i += 1
            continue

        if in_bracket_ident:
            if ch == "]":
                in_bracket_ident = False
            i += 1
            continue

        if ch == "'":
            in_single_quote = True
        elif ch == '"':
            in_double_quote = True
        elif ch == "[":
            in_bracket_ident = True
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i

        i += 1

    return -1


def iter_create_table_blocks(sql: str) -> Iterator[Tuple[str, str]]:
    clean = strip_sql_comments(sql)
    for match in re.finditer(r"\bCREATE\s+TABLE\b", clean, flags=re.I):
        start = match.end()
        i = start
        n = len(clean)

        while i < n and clean[i].isspace():
            i += 1

        ine = re.match(r"IF\s+NOT\s+EXISTS\b", clean[i:], flags=re.I)
        if ine:
            i += ine.end()
            while i < n and clean[i].isspace():
                i += 1

        open_paren = clean.find("(", i)
        if open_paren == -1:
            continue

        header = clean[i:open_paren].strip()
        close_paren = find_matching_paren(clean, open_paren)
        if close_paren == -1:
            continue

        body = clean[open_paren + 1 : close_paren]
        yield header, body


def extract_schema_and_table(table_header: str) -> Tuple[Optional[str], Optional[str]]:
    parts = split_identifier_chain(table_header)
    if not parts:
        return None, None
    if len(parts) == 1:
        return None, parts[0]
    return parts[-2], parts[-1]


def split_top_level_commas(text: str) -> list[str]:
    out: list[str] = []
    buf: list[str] = []
    depth = 0
    i = 0
    n = len(text)
    in_single_quote = False
    in_double_quote = False
    in_bracket_ident = False

    while i < n:
        ch = text[i]

        if in_single_quote:
            buf.append(ch)
            if ch == "'":
                if i + 1 < n and text[i + 1] == "'":
                    buf.append(text[i + 1])
                    i += 2
                    continue
                in_single_quote = False
            i += 1
            continue

        if in_double_quote:
            buf.append(ch)
            if ch == '"':
                in_double_quote = False
            i += 1
            continue

        if in_bracket_ident:
            buf.append(ch)
            if ch == "]":
                in_bracket_ident = False
            i += 1
            continue

        if ch == "'":
            in_single_quote = True
            buf.append(ch)
        elif ch == '"':
            in_double_quote = True
            buf.append(ch)
        elif ch == "[":
            in_bracket_ident = True
            buf.append(ch)
        elif ch == "(":
            depth += 1
            buf.append(ch)
        elif ch == ")":
            depth -= 1
            buf.append(ch)
        elif ch == "," and depth == 0:
            part = "".join(buf).strip()
            if part:
                out.append(part)
            buf = []
        else:
            buf.append(ch)

        i += 1

    tail = "".join(buf).strip()
    if tail:
        out.append(tail)
    return out


def split_top_level_whitespace(text: str) -> list[str]:
    tokens: list[str] = []
    buf: list[str] = []
    depth = 0
    i = 0
    n = len(text)
    in_single_quote = False
    in_double_quote = False
    in_bracket_ident = False

    while i < n:
        ch = text[i]

        if in_single_quote:
            buf.append(ch)
            if ch == "'":
                if i + 1 < n and text[i + 1] == "'":
                    buf.append(text[i + 1])
                    i += 2
                    continue
                in_single_quote = False
            i += 1
            continue

        if in_double_quote:
            buf.append(ch)
            if ch == '"':
                in_double_quote = False
            i += 1
            continue

        if in_bracket_ident:
            buf.append(ch)
            if ch == "]":
                in_bracket_ident = False
            i += 1
            continue

        if ch == "'":
            in_single_quote = True
            buf.append(ch)
        elif ch == '"':
            in_double_quote = True
            buf.append(ch)
        elif ch == "[":
            in_bracket_ident = True
            buf.append(ch)
        elif ch == "(":
            depth += 1
            buf.append(ch)
        elif ch == ")":
            depth -= 1
            buf.append(ch)
        elif ch.isspace() and depth == 0:
            token = "".join(buf).strip()
            if token:
                tokens.append(token)
            buf = []
        else:
            buf.append(ch)

        i += 1

    token = "".join(buf).strip()
    if token:
        tokens.append(token)
    return tokens


def read_leading_identifier(text: str) -> Tuple[Optional[str], str]:
    s = text.lstrip()
    if not s:
        return None, ""

    if s.startswith("["):
        end = s.find("]")
        if end == -1:
            return None, text
        ident = s[: end + 1]
        return normalise_identifier(ident), s[end + 1 :]

    if s[0] in {'"', '`'}:
        quote = s[0]
        end = s.find(quote, 1)
        if end == -1:
            return None, text
        ident = s[: end + 1]
        return normalise_identifier(ident), s[end + 1 :]

    match = re.match(r"([A-Za-z_#][A-Za-z0-9_$#]*)", s)
    if not match:
        return None, text
    ident = match.group(1)
    return ident, s[match.end() :]


def canonicalise_spaces(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip())


def parse_type_spec(remainder: str) -> Tuple[Optional[str], Optional[str], Optional[bool]]:
    tokens = split_top_level_whitespace(remainder)
    if not tokens:
        return None, None, None

    type_tokens: list[str] = []
    stop_index = len(tokens)

    for idx, token in enumerate(tokens):
        upper = token.upper()
        if upper in TYPE_STOP_TOKENS and type_tokens:
            stop_index = idx
            break
        type_tokens.append(token)

    type_expr = canonicalise_spaces(" ".join(type_tokens)) if type_tokens else None
    tail_tokens = tokens[stop_index:]
    tail_upper = " ".join(tail_tokens).upper()

    is_nullable: Optional[bool] = None
    if "NOT NULL" in tail_upper:
        is_nullable = False
    elif re.search(r"(^|\s)NULL(\s|$)", tail_upper):
        is_nullable = True

    if not type_expr:
        return None, None, is_nullable

    type_match = re.match(r"^(?P<dtype>[A-Za-z_][A-Za-z0-9_ ]*?)(?:\s*\((?P<size>.*)\))?$", type_expr)
    if type_match:
        data_type = canonicalise_spaces(type_match.group("dtype")).lower()
        size_text = type_match.group("size")
        if size_text is not None:
            size_text = canonicalise_spaces(size_text)
        return data_type, size_text, is_nullable

    return type_expr.lower(), None, is_nullable


def parse_size_components(data_type: str, size_text: Optional[str]) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    if size_text is None:
        return None, None, None

    parts = [p.strip() for p in size_text.split(",")]
    if data_type in STRING_TYPES:
        return size_text, None, None

    if data_type in NUMERIC_TYPES:
        if len(parts) == 1:
            return None, parts[0], None
        if len(parts) >= 2:
            return None, parts[0], parts[1]

    return size_text, None, None


def parse_column_def(source_system: str, source_file: str, schema_name: Optional[str], table_name: str, ordinal: int, col_def: str) -> Optional[ColumnRecord]:
    stripped = col_def.strip()
    if not stripped:
        return None

    first_word_match = re.match(r"^([A-Za-z_]+)", stripped)
    if first_word_match and first_word_match.group(1).upper() in TABLE_LEVEL_PREFIXES:
        return None

    field_name, remainder = read_leading_identifier(stripped)
    if not field_name:
        return None

    data_type, size_text, is_nullable = parse_type_spec(remainder)
    if not data_type:
        return None

    max_length, numeric_precision, numeric_scale = parse_size_components(data_type, size_text)
    full_type = f"{data_type}({size_text})" if size_text else data_type

    table_name_lower = table_name.lower()
    field_name_lower = field_name.lower()

    return ColumnRecord(
        source_system=source_system,
        source_file=source_file,
        schema_name=schema_name.lower() if schema_name else None,
        table_name=table_name_lower,
        field_name=field_name_lower,
        table_field=f"{table_name_lower}.{field_name_lower}",
        ordinal_position=ordinal,
        data_type=data_type,
        size_text=size_text,
        full_type=full_type,
        max_length=max_length,
        numeric_precision=numeric_precision,
        numeric_scale=numeric_scale,
        is_nullable=is_nullable,
    )


def discover_sql_files(patterns: Sequence[str]) -> list[Path]:
    found: set[Path] = set()
    for pattern in patterns:
        for path_str in glob.glob(pattern, recursive=True):
            path = Path(path_str)
            if path.is_file() and path.suffix.lower() == ".sql":
                found.add(path.resolve())
    return sorted(found)


def extract_source_records(source_system: str, sql_files: Sequence[Path], table_prefix: str) -> list[ColumnRecord]:
    records: list[ColumnRecord] = []
    prefix_lower = table_prefix.lower()

    for sql_file in sql_files:
        try:
            sql_text = sql_file.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            sql_text = sql_file.read_text(encoding="utf-8", errors="replace")

        for header, body in iter_create_table_blocks(sql_text):
            schema_name, table_name = extract_schema_and_table(header)
            if not table_name:
                continue

            table_name = normalise_table_name_for_match(table_name)
            if not table_name:
                continue

            if not table_name.lower().startswith(prefix_lower):
                continue

            column_defs = split_top_level_commas(body)
            ordinal = 0
            for part in column_defs:
                record = parse_column_def(
                    source_system=source_system,
                    source_file=str(sql_file),
                    schema_name=schema_name,
                    table_name=table_name,
                    ordinal=ordinal + 1,
                    col_def=part,
                )
                if record is not None:
                    ordinal += 1
                    records.append(record)

    return records


def build_summary(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return pd.DataFrame(
            columns=[
                "source_system",
                "schema_name",
                "table_name",
                "field_count",
                "first_source_file",
            ]
        )

    summary = (
        df.sort_values(["source_system", "schema_name", "table_name", "ordinal_position"])
        .groupby(["source_system", "schema_name", "table_name"], dropna=False, as_index=False)
        .agg(
            field_count=("field_name", "count"),
            first_source_file=("source_file", "first"),
        )
    )
    return summary


def ensure_output_dir(path: str) -> Path:
    out_dir = Path(path)
    out_dir.mkdir(parents=True, exist_ok=True)
    return out_dir


def write_csv(df: pd.DataFrame, path: Path) -> None:
    df.to_csv(path, index=False, quoting=csv.QUOTE_MINIMAL)


def main() -> int:
    args = parse_args()
    output_dir = ensure_output_dir(args.output_dir)
    source_patterns = load_source_patterns(args.patterns_json)

    all_records: list[ColumnRecord] = []
    file_scan_summary: list[dict[str, object]] = []

    for source_system, patterns in source_patterns.items():
        sql_files = discover_sql_files(patterns)
        file_scan_summary.append(
            {
                "source_system": source_system,
                "sql_file_count": len(sql_files),
            }
        )

        source_records = extract_source_records(
            source_system=source_system,
            sql_files=sql_files,
            table_prefix=args.prefix,
        )
        all_records.extend(source_records)

        source_df = pd.DataFrame([asdict(r) for r in source_records])
        if source_df.empty:
            source_df = pd.DataFrame(
                columns=[field.name for field in ColumnRecord.__dataclass_fields__.values()]
            )

        source_df = source_df.sort_values(
            ["table_name", "ordinal_position", "field_name", "source_file"],
            kind="stable",
        )
        write_csv(source_df, output_dir / f"ssd_ddl_reference_{source_system}.csv")

    all_df = pd.DataFrame([asdict(r) for r in all_records])
    if all_df.empty:
        all_df = pd.DataFrame(columns=[field.name for field in ColumnRecord.__dataclass_fields__.values()])
    else:
        all_df = all_df.sort_values(
            ["source_system", "table_name", "ordinal_position", "field_name", "source_file"],
            kind="stable",
        )

    summary_df = build_summary(all_df)
    file_scan_df = pd.DataFrame(file_scan_summary)

    write_csv(all_df, output_dir / "ssd_ddl_reference_all.csv")
    write_csv(summary_df, output_dir / "ssd_ddl_table_summary.csv")
    write_csv(file_scan_df, output_dir / "ssd_ddl_file_scan_summary.csv")

    print(f"Wrote: {output_dir / 'ssd_ddl_reference_all.csv'}")
    print(f"Wrote: {output_dir / 'ssd_ddl_table_summary.csv'}")
    print(f"Wrote: {output_dir / 'ssd_ddl_file_scan_summary.csv'}")
    for source_system in source_patterns:
        print(f"Wrote: {output_dir / f'ssd_ddl_reference_{source_system}.csv'}")

    if all_df.empty:
        print("No matching SSD CREATE TABLE definitions were found.")
    else:
        print()
        print("Counts by source:")
        print(all_df.groupby("source_system")["table_name"].nunique().rename("tables").to_string())
        print()
        print("Rows extracted by source:")
        print(all_df.groupby("source_system")["field_name"].count().rename("columns").to_string())

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
