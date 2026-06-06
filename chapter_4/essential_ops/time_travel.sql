.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw');
-- ATTACH 'ducklake:local_inst.ducklake' (SNAPSHOT_TIME '2025-05-26 00:00:00');
-- ATTACH 'ducklake:local_inst.ducklake' (SNAPSHOT_VERSION 3);

CREATE OR REPLACE TABLE dl1.sales
as
SELECT 1 as sls_id, DATE '2025-01-01' as sls_dt, 200.05 as sls_amt
UNION ALL
SELECT 2, DATE '2025-03-04', 153.75;

-- Note: the 0 day is there because this is ran as a single batch
-- if you toggle it to 1 day or more, you will get an error because the snapshot doesn't exist
-- in more realistic scenarios, you would have multiple batches and the snapshot from the previous batch would be available for querying in the next batch
-- we are still including it here for demonstration purposes to show how you can query a snapshot from a specific point in time
SELECT * 
FROM dl1.sales
    AT (TIMESTAMP => now() - INTERVAL '0 day');

FROM dl1.snapshots();

USE __ducklake_metadata_dl1;

SELECT 
  s.snapshot_id,
  s.snapshot_time,
  s.schema_version,
  sc.* exclude (snapshot_id)
FROM ducklake_snapshot s
INNER JOIN ducklake_snapshot_changes sc
  		ON s.snapshot_id = sc.snapshot_id
;
