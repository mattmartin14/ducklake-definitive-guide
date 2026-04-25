
-- clean up from previous runs
.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw1"

ATTACH 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH './dw1');

BEGIN TRANSACTION;

    CREATE OR REPLACE TABLE my_ducklake.orders AS
    SELECT 1 as order_id, DATE '2024-01-01' AS order_date, 100.0 AS amount
    UNION ALL
    SELECT 2, DATE '2024-03-04', 150
    ;

    CREATE OR REPLACE TABLE my_ducklake.customers AS
    SELECT 1 as customer_id, 'Alice' as name
    UNION ALL
    SELECT 2, 'Bob'
    ;

COMMIT TRANSACTION;

SELECT * FROM my_ducklake.orders;