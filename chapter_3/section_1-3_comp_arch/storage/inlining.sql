
-- clean up from previous runs
.shell rm -rf -- "local_inst.ducklake" "./ducklake_wh"

ATTACH 'ducklake:local_inst.ducklake' as my_ducklake 
(
    DATA_PATH './ducklake_wh', 
    DATA_INLINING_ROW_LIMIT 3
);

CREATE TABLE my_ducklake.test (id int);

-- this will sit in the inlining buffer
INSERT INTO my_ducklake.test VALUES (1);

-- this will write to disk
INSERT INTO my_ducklake.test VALUES (2), (3), (4), (5);

.print 'contains all ids'
SELECT * FROM my_ducklake.test order by id;

.print 'only contains ids 2-5'
SELECT * FROM read_parquet('./ducklake_wh/main/test/*') order by id;

-- this flushes the single record
CALL ducklake_flush_inlined_data('my_ducklake');
