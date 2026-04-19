#!/usr/bin/env python3
"""Parquet forensic inspector.

Usage:
  uv run python chapter_3/section_4_query_planning/parquet_forensics.py
  uv run python chapter_3/section_4_query_planning/parquet_forensics.py --file other.parquet
"""

from __future__ import annotations

import argparse
from pathlib import Path

import pyarrow.parquet as pq


def fmt_bytes(n: int | None) -> str:
    if n is None:
        return "unknown"
    units = ["B", "KB", "MB", "GB", "TB"]
    value = float(n)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.2f} {unit}" if unit != "B" else f"{int(value)} B"
        value /= 1024
    return f"{n} B"


def print_file_level(meta: pq.FileMetaData, file_path: Path) -> None:
    print("=== FILE-LEVEL METADATA ===")
    print(f"file: {file_path}")
    print(f"created_by: {meta.created_by}")
    print(f"format_version: {meta.format_version}")
    print(f"num_rows: {meta.num_rows}")
    print(f"num_row_groups: {meta.num_row_groups}")
    print(f"serialized_footer_size: {meta.serialized_size} bytes")
    print()


def print_schema(meta: pq.FileMetaData) -> None:
    print("=== SCHEMA ===")
    print(meta.schema)
    print()


def print_row_groups(meta: pq.FileMetaData) -> None:
    print("=== ROW GROUP + COLUMN CHUNK DETAILS ===")
    for rg_idx in range(meta.num_row_groups):
        rg = meta.row_group(rg_idx)
        print(
            f"ROW GROUP {rg_idx}: rows={rg.num_rows}, "
            f"total_byte_size={rg.total_byte_size} ({fmt_bytes(rg.total_byte_size)})"
        )

        for col_idx in range(rg.num_columns):
            col = rg.column(col_idx)
            stats = col.statistics
            print(f"  - column: {col.path_in_schema}")
            print(f"    physical_type: {col.physical_type}")
            print(f"    compression: {col.compression}")
            print(f"    encodings: {list(col.encodings)}")
            print(f"    data_page_offset: {col.data_page_offset}")
            print(f"    dictionary_page_offset: {col.dictionary_page_offset}")
            print(f"    total_compressed_size: {col.total_compressed_size} ({fmt_bytes(col.total_compressed_size)})")
            print(
                "    total_uncompressed_size: "
                f"{col.total_uncompressed_size} ({fmt_bytes(col.total_uncompressed_size)})"
            )
            print(f"    has_dictionary_page: {col.has_dictionary_page}")
            try:
                has_index_page = col.has_index_page
            except NotImplementedError:
                has_index_page = "unsupported_by_pyarrow_build"
            print(f"    has_index_page: {has_index_page}")

            if stats is None:
                print("    stats: missing")
            else:
                print(f"    stats_has_min_max: {stats.has_min_max}")
                print(f"    stats_min: {stats.min}")
                print(f"    stats_max: {stats.max}")
                print(f"    stats_null_count: {stats.null_count}")
                print(f"    stats_distinct_count: {stats.distinct_count}")

        print()


def print_physical_timeline(meta: pq.FileMetaData) -> None:
    print("=== PHYSICAL BYTE TIMELINE (APPROX) ===")
    timeline = []

    for rg_idx in range(meta.num_row_groups):
        rg = meta.row_group(rg_idx)
        for col_idx in range(rg.num_columns):
            col = rg.column(col_idx)
            start = col.data_page_offset
            size = col.total_compressed_size
            end = None if start is None or size is None else start + size - 1
            timeline.append(
                {
                    "row_group": rg_idx,
                    "column": col.path_in_schema,
                    "start": start,
                    "end": end,
                    "size": size,
                }
            )

    timeline.sort(key=lambda x: x["start"] if x["start"] is not None else 10**18)

    for item in timeline:
        if item["start"] is None or item["end"] is None:
            byte_range = "unknown"
        else:
            byte_range = f"{item['start']}..{item['end']}"
        print(
            f"row_group={item['row_group']} column={item['column']} "
            f"bytes={byte_range} size={item['size']}"
        )
    print()


def print_plain_english_construction(meta: pq.FileMetaData) -> None:
    print("=== PLAIN ENGLISH CONSTRUCTION SUMMARY ===")
    print(
        "This Parquet file stores rows in row groups, and each row group stores data "
        "column-by-column in column chunks."
    )
    print(
        f"This file has {meta.num_row_groups} row group(s) for {meta.num_rows} total row(s), "
        "so every query reads at least one row group."
    )
    print(
        "Within each row group, each column chunk has page offsets and compressed sizes, "
        "which tell us where bytes start and how much space they take on disk."
    )
    print(
        "Footer metadata at the end of the file records schema, encodings, compression, "
        "and min/max/null statistics used for pruning."
    )
    print()


def main() -> None:
    parser = argparse.ArgumentParser(description="Inspect Parquet file physical layout and statistics")
    parser.add_argument("--file", default="test.parquet", help="Path to parquet file (default: test.parquet)")
    args = parser.parse_args()

    file_path = Path(args.file)
    if not file_path.exists():
        raise SystemExit(f"File not found: {file_path}")

    parquet_file = pq.ParquetFile(file_path)
    meta = parquet_file.metadata

    print_plain_english_construction(meta)
    print_file_level(meta, file_path)
    print_schema(meta)
    print_row_groups(meta)
    print_physical_timeline(meta)


if __name__ == "__main__":
    main()
