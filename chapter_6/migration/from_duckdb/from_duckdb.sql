.shell rm -f -- "local_inst.ducklake"
.shell rm -f -- "my_duckdb.duckdb"
.shell rm -f -- "my_duckdb.duckdb-wal"
.shell rm -rf -- "./dw"

-- create a new duckdb database
.open my_duckdb.duckdb

CREATE SCHEMA sales;

ATTACH 'tpch.duckdb' AS tpch;

CREATE TABLE sales.orders as select * from tpch.orders;

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

COPY FROM DATABASE my_duckdb.duckdb to dl1;

SELECT * FROM dl1.sales.orders limit 5;