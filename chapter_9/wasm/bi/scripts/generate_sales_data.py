"""Generates dummy data for the `sales_data` DuckLake table.

Produces, under sample_data/:
  - sales_data_template.csv   Header-only template for regional managers to fill in.
  - seed_dummy_data.csv       ~40 rows across 4 "existing" regions, for reference.
  - seed_insert.sql           A single INSERT statement for seed_dummy_data.csv,
                              consumed by scripts/seed_sales_data.sh to pre-populate
                              the live DuckLake table over Quack.
  - sample_upload_<region>.csv  A couple of ready-to-upload CSVs with NEW region
                              names, for testing the WASM portal's upload feature.

Columns: region_name, sls_order_id, sls_dt, item_name, item_quantity, item_total_amt
"""

import csv
import random
from datetime import date, timedelta
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
SAMPLE_DIR = BASE_DIR / "sample_data"
COLUMNS = ["region_name", "sls_order_id", "sls_dt", "item_name", "item_quantity", "item_total_amt"]

ITEMS = [
    ("Widget A", 12.50),
    ("Widget B", 24.00),
    ("Gadget X", 89.99),
    ("Gadget Y", 149.99),
    ("Service Plan - Basic", 39.00),
    ("Service Plan - Pro", 99.00),
    ("Replacement Part Kit", 18.75),
    ("Bulk Supply Case", 210.00),
]

SEED_REGIONS = ["Northeast", "Midwest", "Southwest", "Southeast"]
UPLOAD_REGIONS = ["Pacific Northwest", "Gulf Coast"]

random.seed(42)


def random_date(start: date, end: date) -> date:
    delta_days = (end - start).days
    return start + timedelta(days=random.randint(0, delta_days))


def make_rows(region: str, count: int, order_prefix: str) -> list[dict]:
    rows = []
    start, end = date(2026, 1, 1), date(2026, 8, 31)
    for i in range(1, count + 1):
        item_name, unit_price = random.choice(ITEMS)
        quantity = random.randint(1, 20)
        total = round(unit_price * quantity, 2)
        rows.append(
            {
                "region_name": region,
                "sls_order_id": f"{order_prefix}-{i:04d}",
                "sls_dt": random_date(start, end).isoformat(),
                "item_name": item_name,
                "item_quantity": quantity,
                "item_total_amt": f"{total:.2f}",
            }
        )
    return rows


def write_csv(path: Path, rows: list[dict]) -> None:
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(rows)


def sql_literal(column: str, value: str) -> str:
    if column == "sls_dt":
        return f"DATE '{value}'"
    if column == "item_quantity":
        return str(int(value))
    if column == "item_total_amt":
        return value
    escaped = value.replace("'", "''")
    return f"'{escaped}'"


def write_insert_sql(path: Path, rows: list[dict]) -> None:
    value_tuples = []
    for row in rows:
        literals = [sql_literal(col, row[col]) for col in COLUMNS]
        value_tuples.append(f"  ({', '.join(literals)})")

    columns_sql = ", ".join(COLUMNS)
    sql = (
        f"INSERT INTO dl1.sales_data ({columns_sql}) VALUES\n"
        + ",\n".join(value_tuples)
        + ";\n"
    )
    path.write_text(sql)


def main() -> None:
    SAMPLE_DIR.mkdir(parents=True, exist_ok=True)

    write_csv(SAMPLE_DIR / "sales_data_template.csv", [])

    seed_rows = []
    for region in SEED_REGIONS:
        prefix = "".join(word[0] for word in region.split()).upper()
        seed_rows.extend(make_rows(region, count=10, order_prefix=prefix))
    write_csv(SAMPLE_DIR / "seed_dummy_data.csv", seed_rows)
    write_insert_sql(SAMPLE_DIR / "seed_insert.sql", seed_rows)

    for region in UPLOAD_REGIONS:
        prefix = "".join(word[0] for word in region.split()).upper()
        rows = make_rows(region, count=12, order_prefix=prefix)
        slug = region.lower().replace(" ", "_")
        write_csv(SAMPLE_DIR / f"sample_upload_{slug}.csv", rows)

    print(f"Wrote template + seed + sample upload CSVs to {SAMPLE_DIR}")
    print(f"Seed rows: {len(seed_rows)} across {SEED_REGIONS}")
    print(f"Sample upload CSVs for new regions: {UPLOAD_REGIONS}")


if __name__ == "__main__":
    main()
