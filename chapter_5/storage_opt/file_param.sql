.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

USE dl1;

FROM dl1.options();

CALL dl1.set_option('parquet_version', '2.0');

-- in order to adjust the row group size, need to disable insertion order preservation
SET preserve_insertion_order = false;
CALL dl1.set_option('parquet_row_group_size_bytes', '1GB'); -- 1GB

CALL dl1.set_option('parquet_row_group_size', '10000');

-- sets ducklake compression global setting
CALL dl1.set_option('parquet_compression', 'zstd');

CREATE SCHEMA sales;
CREATE TABLE dl1.sales.sales_dly (sls_dt date, region_name varchar, sls_amt double);

-- you can go further grain on the compression at a schema or table level if needed
CALL dl1.set_option('parquet_compression', 'zstd', schema => 'sales');

CALL dl1.set_option('parquet_compression', 'zstd', schema => 'sales', table_name => 'sales_dly');

INSERT INTO dl1.sales.sales_dly VALUES ('2025-01-01', 'North', 200.05);

SELECT * FROM dl1.sales.sales_dly;