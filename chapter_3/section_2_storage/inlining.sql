ATTACH OR REPLACE 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH concat(getenv('HOME'), '/dw3'), DATA_INLINING_ROW_LIMIT 3);

CREATE OR REPLACE TABLE my_ducklake.orders
AS
SELECT 1 as order_id, DATE '2024-01-01' AS order_date, 100.0 AS amount
;