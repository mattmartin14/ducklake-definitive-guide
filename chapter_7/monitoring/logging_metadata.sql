.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"
.shell rm -rf -- "./logs"

INSTALL TPCH; LOAD TPCH;
CALL dbgen(sf=.001);
ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw');

--CALL enable_logging('DuckLakeMetadata');

CALL enable_logging('DuckLakeMetadata', storage_path = './logs/ducklake_logs');

CREATE TABLE dl1.orders as SELECT * FROM orders;

SELECT catalog, elapsed_ms, query
FROM duckdb_logs_parsed('DuckLakeMetadata');