.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw');

USE dl1;

CREATE table sales_dly (sls_dt date, region_name varchar, sls_amt double);

INSERT INTO sales_dly VALUES ('2025-01-01', 'North', 200.05);

USE __ducklake_metadata_dl1;

CREATE INDEX idx_col_stats on ducklake_file_column_stats (table_id, column_id);

SET memory_limit='4GB';