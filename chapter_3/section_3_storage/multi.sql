-- clean up from previous runs
.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 10);

CREATE OR REPLACE TABLE my_ducklake.orders (order_id INTEGER, order_date TEXT, amount decimal(10, 2));

INSERT INTO my_ducklake.orders (order_id, order_date, amount)
VALUES 
    (1, '2024-01-01', 100.05),
    (2, '2024-01-02', 200.10),
    (3, '2024-01-03', 300.15),
    (4, '2024-01-04', 400.20),
    (5, '2024-01-05', 500.25)
;

USE __ducklake_metadata_my_ducklake;

.print 'After initial insert:'
SELECT data_file_id, begin_snapshot, end_snapshot, path
FROM ducklake_data_file
ORDER BY data_file_id;

UPDATE my_ducklake.orders SET amount = 50.25 WHERE ORDER_ID = 1;

.print 'After update:'
SELECT data_file_id, begin_snapshot, end_snapshot, path
FROM ducklake_data_file
ORDER BY data_file_id;

DELETE FROM my_ducklake.orders WHERE order_id = 2;

.print 'After delete:'
SELECT data_file_id, begin_snapshot, end_snapshot, path
FROM ducklake_data_file
ORDER BY data_file_id;

select * from my_ducklake.orders;