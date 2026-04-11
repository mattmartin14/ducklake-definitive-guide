-- clean up from previous runs
.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

CREATE OR REPLACE TABLE my_ducklake.orders (order_id INTEGER, order_date TEXT, amount decimal(10, 2));

INSERT INTO my_ducklake.orders (order_id, order_date, amount)
VALUES (1, '2024-01-01', 100.05);
