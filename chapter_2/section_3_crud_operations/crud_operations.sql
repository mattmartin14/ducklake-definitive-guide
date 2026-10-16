.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH './dw');

-- CTAS
CREATE OR REPLACE TABLE my_ducklake.cust_orders
AS
SELECT 1001 as order_id, DATE '2024-01-01' AS order_date, 'C001' AS customer_id
UNION ALL
SELECT 1002, DATE '2024-01-02', 'C002'
UNION ALL
SELECT 1003, DATE '2024-01-03', 'C003'
;

-- INSERT INTO
INSERT INTO my_ducklake.cust_orders
VALUES (1004, '2024-01-04', 'C004');

-- UPDATE
UPDATE my_ducklake.cust_orders
SET order_date = '2024-01-05'
WHERE order_id = 1004;

-- DELETE
DELETE FROM my_ducklake.cust_orders
WHERE order_id = 1003;

.print '<< changes to the table >>';

-- View Table
SELECT *
FROM my_ducklake.cust_orders;

-- Merge setup (create a temp table with some updates and new records)
CREATE TABLE my_ducklake.tmp_orders AS
SELECT order_id
    , date_add(order_date, INTERVAL '1 day')::date AS order_date
    , customer_id
FROM my_ducklake.cust_orders;

-- now merge
MERGE INTO my_ducklake.cust_orders AS target
    USING my_ducklake.tmp_orders AS source
        ON target.order_id = source.order_id
    WHEN MATCHED THEN UPDATE 
    WHEN NOT MATCHED THEN INSERT BY NAME
;

.print '<< after merge >>'

-- view changes to the table 
SELECT *
FROM my_ducklake.cust_orders;