.shell rm -f -- "local_inst.ducklake"
.shell rm -f -- "my_duckdb"
.shell rm -f -- "my_duckdb-wal"
.shell rm -rf -- "./dw"

-- create a new duckdb database
.open my_duckdb
install tpch; load tpch;
call dbgen(sf=0.001);

CREATE TABLE orders1 as select * from orders limit 5;

-- drop all TPCH base tables so only the 5-row sample is in my_duckdb
DROP TABLE orders;
DROP TABLE lineitem;
DROP TABLE customer;
DROP TABLE nation;
DROP TABLE part;
DROP TABLE partsupp;
DROP TABLE region;
DROP TABLE supplier;


ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

COPY FROM DATABASE my_duckdb to dl1;

SELECT * FROM dl1.orders1;