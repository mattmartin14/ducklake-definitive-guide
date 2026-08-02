.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);
USE dl1;

CREATE TABLE dl1.orders (
    o_orderkey BIGINT,
    o_orderstatus VARCHAR,
    o_totalprice DOUBLE
);

INSERT INTO dl1.orders VALUES
    (1, 'O', 100.0),
    (2, 'O', 150.0),
    (3, 'O', 180.0);

INSERT INTO dl1.orders VALUES
    (4, 'P', 210.0),
    (5, 'P', 260.0);

UPDATE dl1.orders
SET o_totalprice = o_totalprice + 25
WHERE o_orderkey IN (1, 2);

DELETE FROM dl1.orders
WHERE o_orderkey = 3;

CALL ducklake_merge_adjacent_files('dl1');

-- Use a future cutoff to expire all historical snapshots in this demo run.
CALL ducklake_expire_snapshots('dl1', older_than => now() + INTERVAL '1 day');

CREATE TABLE dl1.old_files_log (log_ts timestamp, file_path varchar(250));
INSERT INTO dl1.old_files_log (log_ts, file_path)
SELECT current_timestamp, p.path
FROM ducklake_cleanup_old_files(
    'dl1',
    dry_run => true,
    older_than => now()
) as p;

SELECT * FROM dl1.old_files_log;

