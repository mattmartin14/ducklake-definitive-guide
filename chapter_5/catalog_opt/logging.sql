.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw');

USE dl1;

CREATE table sales_dly (sls_dt date, region_name varchar, sls_amt double);

.print 'test1'


--CALL enable_logging('DuckLakeMetadata', storage = 'memory');
CALL enable_logging('DuckLakeMetadata');

INSERT INTO sales_dly VALUES ('2025-01-01', 'North', 200.05);

SELECT catalog, elapsed_ms, query
FROM duckdb_logs_parsed('DuckLakeMetadata');


EXPLAIN ANALYZE
SELECT *
FROM sales_dly
WHERE sls_dt = '2025-01-01'
    AND region_name = 'North';