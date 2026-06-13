.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

USE dl1;

CREATE TABLE dl1.sales_dly (sls_dt date, region_name varchar, sls_amt double); 
INSERT INTO dl1.sales_dly VALUES ('2025-01-01', 'North', 200.05);
INSERT INTO dl1.sales_dly VALUES ('2025-01-02', 'North', 210.05);
INSERT INTO dl1.sales_dly VALUES ('2025-01-03', 'North', 220.05);
INSERT INTO dl1.sales_dly VALUES ('2025-01-04', 'North', 230.05);

-- merge the files (compaction) (creates a new parquet file, maintains snapshot history)
CALL ducklake_merge_adjacent_files('dl1');

-- expires the older files
CALL ducklake_expire_snapshots('dl1', older_than => now() - INTERVAL '1 week');

-- global setting to auto expire
CALL dl1.set_option('expire_older_than', '1 month');

-- removes the older/expired snapshot files
CALL ducklake_cleanup_old_files('dl1', cleanup_all => true);


SELECT * FROM dl1.sales_dly;