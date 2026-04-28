-- clean up from previous runs
.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

CREATE OR REPLACE TABLE my_ducklake.orders (order_id INTEGER, order_date DATE, amount decimal(10, 2));

INSERT INTO my_ducklake.orders (order_id, order_date, amount)
VALUES 
    (1, '2024-01-01', 100.05),
    (2, '2024-01-02', 150.00),
    (3, '2024-01-03', 200.25)
;

USE __ducklake_metadata_my_ducklake;

--select * from information_schema.tables;

.print 'table stats e.g. count *';
SELECT ts.record_count
FROM ducklake_table_stats as ts
    INNER JOIN ducklake_table as t
        ON ts.table_id = t.table_id
WHERE t.table_name = 'orders'
;

.print 'readable column stats'
SELECT c.column_id, c.column_name, cs.column_size_bytes, cs.value_count, cs.null_count, cs.min_value, cs.max_value
FROM ducklake_column as c
    INNER JOIN ducklake_file_column_stats as cs
        ON c.column_id = cs.column_id
    INNER JOIN ducklake_table as t
        ON c.table_id = t.table_id
WHERE t.table_name = 'orders'
ORDER BY c.column_id
;

.print 'examining internals of a parquet file'
SELECT row_group_id, path_in_schema AS column_name, type
    , stats_min, stats_max, stats_null_count, num_values, compression, encodings 
FROM parquet_metadata('./dw/main/orders/*.parquet') 
where column_name = 'amount'
ORDER BY row_group_id, path_in_schema;


.print 'snapshot metadata';
SELECT s.snapshot_id, s.snapshot_time
FROM ducklake_snapshot as s
    INNER JOIN ducklake_table as t
        on s.snapshot_id = t.begin_snapshot
WHERE t.table_name = 'orders'
;

