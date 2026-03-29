
-- clean up from previous runs
.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "$HOME/dw3"

ATTACH 'ducklake:local_inst.ducklake' as my_ducklake 
    (DATA_PATH concat(getenv('HOME'), '/dw3'), DATA_INLINING_ROW_LIMIT 3);

CREATE TABLE my_ducklake.test (id int);

-- this will sit in the inlining buffer
INSERT INTO my_ducklake.test VALUES (1);

-- this will write to disk
INSERT INTO my_ducklake.test VALUES (2), (3), (4), (5);

-- this will also write to disk
INSERT INTO my_ducklake.test
SELECT * 
FROM range(6, 10);

SELECT * FROM my_ducklake.test order by id;

SELECT * FROM read_parquet('~/dw3/main/test/*') order by id;

-- this flushes the single record
CALL ducklake_flush_inlined_data('my_ducklake');