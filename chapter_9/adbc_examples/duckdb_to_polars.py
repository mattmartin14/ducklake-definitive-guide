"""Query DuckLake with ADBC and transfer the result to Polars via Arrow."""

# Run: uv run python chapter_9/adbc_examples/duckdb_to_polars.py

from pathlib import Path

import duckdb
import polars as pl
import sys
from adbc_driver_duckdb import dbapi


CATALOG_PATH = Path(__file__).with_name("metadata.ducklake")
DATA_PATH = Path(__file__).with_name("lake_data")

def create_ducklake_table() -> None:
	"""Create a small DuckLake table with DuckDB's native Python API."""
	with duckdb.connect() as connection:
		connection.execute("INSTALL ducklake; LOAD ducklake;")
		connection.execute(
			f"""
			ATTACH 'ducklake:{CATALOG_PATH}' AS lake (
				DATA_PATH '{DATA_PATH}'
			)
			"""
		)
		connection.execute(
			"""
			CREATE OR REPLACE TABLE lake.trips AS
			SELECT * FROM (VALUES
				(1, 'city_0', 1.5),
				(2, 'city_1', 3.0),
				(3, 'city_2', 4.5)
			) AS trips(id, city, fare)
			"""
		)


def query_with_adbc() -> pl.DataFrame:
	"""Query DuckLake through ADBC and construct a Polars DataFrame."""
	with dbapi.connect() as connection:
		with connection.cursor() as cursor:
			cursor.execute(f"ATTACH 'ducklake:{CATALOG_PATH}' AS lake")
			cursor.execute(
				"""
				SELECT city, count(*) AS trips, sum(fare) AS total
				FROM lake.trips
				GROUP BY city
				ORDER BY city
				"""
			)
			arrow_table = cursor.fetch_arrow_table()

	# Polars consumes the Arrow table without a pandas or row-by-row copy.
	return pl.from_arrow(arrow_table, rechunk=False)


def main() -> None:
	create_ducklake_table()
	trips = query_with_adbc()

	print(trips)
	print(f"shape: {trips.shape}")

	assert trips.shape == (3, 3)
	assert trips.columns == ["city", "trips", "total"]

if __name__ == "__main__":
	sys.exit(main())


