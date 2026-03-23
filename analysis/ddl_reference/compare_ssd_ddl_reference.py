#!/usr/bin/env python3
# python ./analysis/ddl_reference/compare_ssd_ddl_reference.py --input-dir ./analysis/ddl_reference


"""
Compare extracted SSD DDL reference CSVs across Mosaic, System C, and Eclipse.

- detect and report duplicate rows within each source
- collapse duplicates to one canonical row per source/table/field before
  cross-source comparison
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import pandas as pd

EXPECTED_SOURCES = ["mosaic", "systemc", "eclipse"]
PAIRWISE = [("mosaic", "systemc"), ("mosaic", "eclipse"), ("systemc", "eclipse")]

REQUIRED_COLUMNS = [
    "source_system",
    "source_file",
    "table_name",
    "field_name",
    "ordinal_position",
    "data_type",
    "size_text",
    "full_type",
    "max_length",
    "numeric_precision",
    "numeric_scale",
    "is_nullable",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Compare extracted SSD DDL reference CSVs")
    parser.add_argument(
        "--input-dir",
        default="./analysis/ddl_reference",
        help="Directory containing the per-source ssd_ddl_reference_*.csv files",
    )
    parser.add_argument(
        "--output-dir",
        default="",
        help="Directory to write comparison CSVs into, defaults to input-dir",
    )
    return parser.parse_args()


def ensure_dir(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def write_csv(df: pd.DataFrame, path: Path) -> None:
    df.to_csv(path, index=False, quoting=csv.QUOTE_MINIMAL)


def normalise_nullable(series: pd.Series) -> pd.Series:
    return (
        series.astype("string")
        .str.strip()
        .str.lower()
        .replace(
            {
                "true": "true",
                "false": "false",
                "1": "true",
                "0": "false",
                "yes": "true",
                "no": "false",
                "nan": pd.NA,
                "<na>": pd.NA,
                "none": pd.NA,
                "": pd.NA,
            }
        )
    )


def read_source_csv(path: Path, source_name: str) -> pd.DataFrame:
    if not path.exists():
        return pd.DataFrame(columns=REQUIRED_COLUMNS)

    df = pd.read_csv(path)

    for col in REQUIRED_COLUMNS:
        if col not in df.columns:
            df[col] = pd.NA

    df = df[REQUIRED_COLUMNS].copy()
    df["source_system"] = source_name

    text_cols = [
        "source_file",
        "table_name",
        "field_name",
        "data_type",
        "size_text",
        "full_type",
        "max_length",
        "numeric_precision",
        "numeric_scale",
    ]
    for col in text_cols:
        df[col] = df[col].astype("string").str.strip().str.lower()

    df["ordinal_position"] = pd.to_numeric(df["ordinal_position"], errors="coerce").astype("Int64")
    df["is_nullable"] = normalise_nullable(df["is_nullable"])

    df = df.dropna(subset=["table_name", "field_name"], how="any")
    return df


def first_non_null(series: pd.Series):
    non_null = series.dropna()
    return non_null.iloc[0] if not non_null.empty else pd.NA


def build_duplicate_report(all_df: pd.DataFrame) -> pd.DataFrame:
    if all_df.empty:
        return pd.DataFrame(columns=[
            "source_system", "table_name", "field_name", "raw_row_count",
            "source_file_count", "distinct_full_type_count", "distinct_size_count",
            "distinct_nullable_count", "distinct_ordinal_count", "source_files"
        ])

    grouped = (
        all_df.groupby(["source_system", "table_name", "field_name"], dropna=False, as_index=False)
        .agg(
            raw_row_count=("field_name", "count"),
            source_file_count=("source_file", lambda s: s.dropna().nunique()),
            distinct_full_type_count=("full_type", lambda s: s.dropna().nunique()),
            distinct_size_count=("size_text", lambda s: s.dropna().nunique()),
            distinct_nullable_count=("is_nullable", lambda s: s.dropna().nunique()),
            distinct_ordinal_count=("ordinal_position", lambda s: s.dropna().nunique()),
            source_files=("source_file", lambda s: " | ".join(sorted(set(x for x in s.dropna().astype(str) if x)))),
        )
    )
    grouped = grouped.loc[grouped["raw_row_count"] > 1].copy()
    return grouped.sort_values(["source_system", "table_name", "field_name"], kind="stable").reset_index(drop=True)


def collapse_source_duplicates(all_df: pd.DataFrame) -> pd.DataFrame:
    if all_df.empty:
        return all_df.copy()

    df = all_df.sort_values(
        ["source_system", "table_name", "field_name", "ordinal_position", "source_file"],
        kind="stable",
        na_position="last",
    ).copy()

    collapsed = (
        df.groupby(["source_system", "table_name", "field_name"], dropna=False, as_index=False)
        .agg(
            source_file=("source_file", first_non_null),
            ordinal_position=("ordinal_position", first_non_null),
            data_type=("data_type", first_non_null),
            size_text=("size_text", first_non_null),
            full_type=("full_type", first_non_null),
            max_length=("max_length", first_non_null),
            numeric_precision=("numeric_precision", first_non_null),
            numeric_scale=("numeric_scale", first_non_null),
            is_nullable=("is_nullable", first_non_null),
            raw_duplicate_row_count=("field_name", "count"),
            duplicate_full_type_count=("full_type", lambda s: s.dropna().nunique()),
            duplicate_size_count=("size_text", lambda s: s.dropna().nunique()),
            duplicate_nullable_count=("is_nullable", lambda s: s.dropna().nunique()),
            duplicate_ordinal_count=("ordinal_position", lambda s: s.dropna().nunique()),
        )
    )

    collapsed["has_duplicate_rows_in_source"] = collapsed["raw_duplicate_row_count"] > 1
    collapsed["has_within_source_type_conflict"] = collapsed["duplicate_full_type_count"] > 1
    collapsed["has_within_source_size_conflict"] = collapsed["duplicate_size_count"] > 1
    collapsed["has_within_source_nullable_conflict"] = collapsed["duplicate_nullable_count"] > 1
    collapsed["has_within_source_ordinal_conflict"] = collapsed["duplicate_ordinal_count"] > 1

    return collapsed


def build_table_presence(deduped_df: pd.DataFrame) -> pd.DataFrame:
    tables = pd.DataFrame({"table_name": sorted(deduped_df["table_name"].dropna().unique())})
    result = tables.copy()

    for source in EXPECTED_SOURCES:
        src = deduped_df.loc[deduped_df["source_system"] == source].copy()
        if src.empty:
            summary = pd.DataFrame(columns=[
                "table_name", f"present_{source}", f"field_count_{source}", f"raw_field_rows_{source}"
            ])
        else:
            summary = (
                src.groupby("table_name", as_index=False)
                .agg(
                    **{
                        f"field_count_{source}": ("field_name", "count"),
                        f"raw_field_rows_{source}": ("raw_duplicate_row_count", "sum"),
                    }
                )
            )
            summary[f"present_{source}"] = True

        result = result.merge(summary, on="table_name", how="left")
        result[f"present_{source}"] = result[f"present_{source}"].fillna(False)
        result[f"field_count_{source}"] = pd.to_numeric(result[f"field_count_{source}"], errors="coerce").astype("Int64")
        result[f"raw_field_rows_{source}"] = pd.to_numeric(result[f"raw_field_rows_{source}"], errors="coerce").astype("Int64")

    present_cols = [f"present_{s}" for s in EXPECTED_SOURCES]
    field_count_cols = [f"field_count_{s}" for s in EXPECTED_SOURCES]

    result["present_in_sources"] = result[present_cols].sum(axis=1)
    result["present_in_all_3"] = result["present_in_sources"].eq(3)

    counts_same = []
    for _, row in result.iterrows():
        counts = [row[c] for c in field_count_cols if pd.notna(row[c])]
        counts_same.append(len(set(counts)) <= 1 if counts else False)
    result["field_count_same_where_present"] = counts_same

    return result.sort_values("table_name", kind="stable").reset_index(drop=True)


def build_column_matrix(deduped_df: pd.DataFrame) -> pd.DataFrame:
    base = (
        deduped_df[["table_name", "field_name"]]
        .drop_duplicates()
        .sort_values(["table_name", "field_name"], kind="stable")
        .reset_index(drop=True)
    )

    result = base.copy()

    for source in EXPECTED_SOURCES:
        src = deduped_df.loc[deduped_df["source_system"] == source, [
            "table_name", "field_name", "ordinal_position", "data_type", "size_text",
            "full_type", "max_length", "numeric_precision", "numeric_scale", "is_nullable",
            "raw_duplicate_row_count", "has_duplicate_rows_in_source", "has_within_source_type_conflict",
            "has_within_source_size_conflict", "has_within_source_nullable_conflict",
            "has_within_source_ordinal_conflict",
        ]].copy()

        src = src.rename(columns={
            "ordinal_position": f"ordinal_{source}",
            "data_type": f"data_type_{source}",
            "size_text": f"size_text_{source}",
            "full_type": f"full_type_{source}",
            "max_length": f"max_length_{source}",
            "numeric_precision": f"numeric_precision_{source}",
            "numeric_scale": f"numeric_scale_{source}",
            "is_nullable": f"is_nullable_{source}",
            "raw_duplicate_row_count": f"raw_duplicate_row_count_{source}",
            "has_duplicate_rows_in_source": f"has_duplicate_rows_in_source_{source}",
            "has_within_source_type_conflict": f"has_within_source_type_conflict_{source}",
            "has_within_source_size_conflict": f"has_within_source_size_conflict_{source}",
            "has_within_source_nullable_conflict": f"has_within_source_nullable_conflict_{source}",
            "has_within_source_ordinal_conflict": f"has_within_source_ordinal_conflict_{source}",
        })

        result = result.merge(src, on=["table_name", "field_name"], how="left")
        result[f"present_{source}"] = result[f"full_type_{source}"].notna() | result[f"ordinal_{source}"].notna()

    present_cols = [f"present_{s}" for s in EXPECTED_SOURCES]
    result["present_in_sources"] = result[present_cols].sum(axis=1)
    result["present_in_all_3"] = result["present_in_sources"].eq(3)
    result["same_field_presence_all_3"] = result["present_in_sources"].isin([0, 3])

    def same_across(row: pd.Series, prefix: str) -> bool:
        vals = [row[f"{prefix}_{s}"] for s in EXPECTED_SOURCES if pd.notna(row[f"{prefix}_{s}"])]
        if len(vals) <= 1:
            return True
        return len(set(vals)) == 1

    result["same_data_type_where_present"] = result.apply(lambda r: same_across(r, "data_type"), axis=1)
    result["same_size_text_where_present"] = result.apply(lambda r: same_across(r, "size_text"), axis=1)
    result["same_full_type_where_present"] = result.apply(lambda r: same_across(r, "full_type"), axis=1)
    result["same_nullable_where_present"] = result.apply(lambda r: same_across(r, "is_nullable"), axis=1)
    result["same_ordinal_where_present"] = result.apply(lambda r: same_across(r, "ordinal"), axis=1)

    return result.sort_values(["table_name", "field_name"], kind="stable").reset_index(drop=True)


def build_table_summary(table_presence: pd.DataFrame, column_matrix: pd.DataFrame) -> pd.DataFrame:
    if column_matrix.empty:
        diff_rollup = pd.DataFrame(columns=[
            "table_name", "column_rows_considered", "field_name_set_same_all_3",
            "full_type_same_all_common_fields", "size_same_all_common_fields",
            "nullable_same_all_common_fields", "ordinal_same_all_common_fields",
            "missing_field_rows", "type_mismatch_rows", "size_mismatch_rows",
            "nullable_mismatch_rows", "ordinal_mismatch_rows",
            "common_fields_with_any_within_source_duplicates",
            "common_fields_with_any_within_source_conflicts",
        ])
    else:
        cm = column_matrix.copy()
        grouped = []
        for table_name, grp in cm.groupby("table_name", dropna=False):
            missing_field_rows = int((grp["present_in_sources"] != 3).sum())
            common = grp.loc[grp["present_in_all_3"]].copy()

            duplicate_flag_cols = [f"has_duplicate_rows_in_source_{s}" for s in EXPECTED_SOURCES if f"has_duplicate_rows_in_source_{s}" in common.columns]
            conflict_flag_cols = []
            for suffix in ["type", "size", "nullable", "ordinal"]:
                conflict_flag_cols.extend([
                    f"has_within_source_{suffix}_conflict_{s}"
                    for s in EXPECTED_SOURCES
                    if f"has_within_source_{suffix}_conflict_{s}" in common.columns
                ])

            grouped.append({
                "table_name": table_name,
                "column_rows_considered": len(grp),
                "field_name_set_same_all_3": missing_field_rows == 0,
                "full_type_same_all_common_fields": bool(common["same_full_type_where_present"].all()) if not common.empty else True,
                "size_same_all_common_fields": bool(common["same_size_text_where_present"].all()) if not common.empty else True,
                "nullable_same_all_common_fields": bool(common["same_nullable_where_present"].all()) if not common.empty else True,
                "ordinal_same_all_common_fields": bool(common["same_ordinal_where_present"].all()) if not common.empty else True,
                "missing_field_rows": missing_field_rows,
                "type_mismatch_rows": int((common["same_full_type_where_present"] == False).sum()),
                "size_mismatch_rows": int((common["same_size_text_where_present"] == False).sum()),
                "nullable_mismatch_rows": int((common["same_nullable_where_present"] == False).sum()),
                "ordinal_mismatch_rows": int((common["same_ordinal_where_present"] == False).sum()),
                "common_fields_with_any_within_source_duplicates": int(common[duplicate_flag_cols].fillna(False).any(axis=1).sum()) if duplicate_flag_cols else 0,
                "common_fields_with_any_within_source_conflicts": int(common[conflict_flag_cols].fillna(False).any(axis=1).sum()) if conflict_flag_cols else 0,
            })
        diff_rollup = pd.DataFrame(grouped)

    out = table_presence.merge(diff_rollup, on="table_name", how="left")

    fill_false_cols = [
        "field_name_set_same_all_3", "full_type_same_all_common_fields", "size_same_all_common_fields",
        "nullable_same_all_common_fields", "ordinal_same_all_common_fields",
    ]
    for col in fill_false_cols:
        out[col] = out[col].fillna(False)

    fill_zero_cols = [
        "column_rows_considered", "missing_field_rows", "type_mismatch_rows", "size_mismatch_rows",
        "nullable_mismatch_rows", "ordinal_mismatch_rows",
        "common_fields_with_any_within_source_duplicates",
        "common_fields_with_any_within_source_conflicts",
    ]
    for col in fill_zero_cols:
        out[col] = pd.to_numeric(out[col], errors="coerce").fillna(0).astype(int)

    out["all_three_match_cleanly"] = (
        out["present_in_all_3"]
        & out["field_count_same_where_present"]
        & out["field_name_set_same_all_3"]
        & out["full_type_same_all_common_fields"]
        & out["size_same_all_common_fields"]
        & out["nullable_same_all_common_fields"]
        & out["ordinal_same_all_common_fields"]
        & out["common_fields_with_any_within_source_conflicts"].eq(0)
    )

    return out.sort_values("table_name", kind="stable").reset_index(drop=True)


def build_pairwise_summary(deduped_df: pd.DataFrame) -> pd.DataFrame:
    rows = []
    all_tables = sorted(deduped_df["table_name"].dropna().unique())

    for left, right in PAIRWISE:
        left_df = deduped_df.loc[deduped_df["source_system"] == left].copy()
        right_df = deduped_df.loc[deduped_df["source_system"] == right].copy()

        left_tables = set(left_df["table_name"].dropna().unique())
        right_tables = set(right_df["table_name"].dropna().unique())

        for table in all_tables:
            ltab = left_df.loc[left_df["table_name"] == table, ["field_name", "ordinal_position", "full_type", "size_text", "is_nullable"]].copy()
            rtab = right_df.loc[right_df["table_name"] == table, ["field_name", "ordinal_position", "full_type", "size_text", "is_nullable"]].copy()

            present_left = table in left_tables
            present_right = table in right_tables

            field_count_left = len(ltab) if present_left else pd.NA
            field_count_right = len(rtab) if present_right else pd.NA

            lfields = set(ltab["field_name"].dropna().tolist())
            rfields = set(rtab["field_name"].dropna().tolist())
            common_fields = sorted(lfields & rfields)

            merged = ltab.merge(rtab, on="field_name", how="outer", suffixes=(f"_{left}", f"_{right}"))
            missing_fields = int((merged[f"full_type_{left}"].isna() | merged[f"full_type_{right}"].isna()).sum())

            common_only = merged.loc[merged[f"full_type_{left}"].notna() & merged[f"full_type_{right}"].notna()].copy()

            type_mismatches = int((common_only[f"full_type_{left}"] != common_only[f"full_type_{right}"]).sum())
            size_mismatches = int((common_only[f"size_text_{left}"] != common_only[f"size_text_{right}"]).sum())
            nullable_mismatches = int((common_only[f"is_nullable_{left}"] != common_only[f"is_nullable_{right}"]).sum())
            ordinal_mismatches = int((common_only[f"ordinal_position_{left}"] != common_only[f"ordinal_position_{right}"]).sum())

            rows.append({
                "left_source": left,
                "right_source": right,
                "table_name": table,
                f"present_{left}": present_left,
                f"present_{right}": present_right,
                f"field_count_{left}": field_count_left,
                f"field_count_{right}": field_count_right,
                "table_present_in_both": present_left and present_right,
                "field_count_same": field_count_left == field_count_right if present_left and present_right else False,
                "field_name_set_same": lfields == rfields if present_left and present_right else False,
                "common_field_count": len(common_fields),
                "missing_field_rows": missing_fields,
                "type_mismatch_rows": type_mismatches,
                "size_mismatch_rows": size_mismatches,
                "nullable_mismatch_rows": nullable_mismatches,
                "ordinal_mismatch_rows": ordinal_mismatches,
                "pair_matches_cleanly": (
                    present_left and present_right and field_count_left == field_count_right and lfields == rfields
                    and type_mismatches == 0 and size_mismatches == 0 and nullable_mismatches == 0 and ordinal_mismatches == 0
                ),
            })

    return pd.DataFrame(rows).sort_values(["left_source", "right_source", "table_name"], kind="stable").reset_index(drop=True)


def main() -> int:
    args = parse_args()
    input_dir = Path(args.input_dir)
    output_dir = ensure_dir(Path(args.output_dir) if args.output_dir else input_dir)

    source_frames = []
    for source in EXPECTED_SOURCES:
        path = input_dir / f"ssd_ddl_reference_{source}.csv"
        source_frames.append(read_source_csv(path, source))

    all_df = pd.concat(source_frames, ignore_index=True)

    if not all_df.empty:
        all_df = all_df.sort_values(["source_system", "table_name", "ordinal_position", "field_name", "source_file"], kind="stable")

    duplicate_report = build_duplicate_report(all_df)
    deduped_df = collapse_source_duplicates(all_df)

    table_presence = build_table_presence(deduped_df) if not deduped_df.empty else pd.DataFrame()
    column_matrix = build_column_matrix(deduped_df) if not deduped_df.empty else pd.DataFrame(columns=["table_name", "field_name"])
    table_summary = build_table_summary(table_presence, column_matrix) if not table_presence.empty else pd.DataFrame()
    differences_only = table_summary.loc[table_summary["all_three_match_cleanly"] == False].copy() if not table_summary.empty else pd.DataFrame()
    pairwise_summary = build_pairwise_summary(deduped_df) if not deduped_df.empty else pd.DataFrame()

    write_csv(duplicate_report, output_dir / "ddl_compare_duplicate_rows_by_source.csv")
    write_csv(deduped_df, output_dir / "ddl_compare_deduped_input_rows.csv")
    write_csv(table_presence, output_dir / "ddl_compare_table_presence.csv")
    write_csv(column_matrix, output_dir / "ddl_compare_column_matrix.csv")
    write_csv(table_summary, output_dir / "ddl_compare_table_summary.csv")
    write_csv(differences_only, output_dir / "ddl_compare_table_differences_only.csv")
    write_csv(pairwise_summary, output_dir / "ddl_compare_pairwise_table_summary.csv")

    print(f"Wrote: {output_dir / 'ddl_compare_duplicate_rows_by_source.csv'}")
    print(f"Wrote: {output_dir / 'ddl_compare_deduped_input_rows.csv'}")
    print(f"Wrote: {output_dir / 'ddl_compare_table_presence.csv'}")
    print(f"Wrote: {output_dir / 'ddl_compare_column_matrix.csv'}")
    print(f"Wrote: {output_dir / 'ddl_compare_table_summary.csv'}")
    print(f"Wrote: {output_dir / 'ddl_compare_table_differences_only.csv'}")
    print(f"Wrote: {output_dir / 'ddl_compare_pairwise_table_summary.csv'}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
