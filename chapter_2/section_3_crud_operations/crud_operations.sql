ATTACH OR REPLACE 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH concat(getenv('HOME'), '/dw1'));

-- CTAS
CREATE OR REPLACE TABLE my_ducklake.cust_orders
AS
SELECT 1001 as order_id, DATE '2024-01-01' AS order_date, 'C001' AS customer_id
UNION ALL
SELECT 1002, DATE '2024-01-02', 'C002'
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

SELECT '<< changes to the table >>' AS info;

-- View Table
SELECT *
FROM my_ducklake.cust_orders;

-- Merge setup (create a temp table with some updates and new records)
CREATE OR REPLACE TABLE my_ducklake.tmp_orders AS
SELECT order_id, date_add(order_date, INTERVAL '1 day') AS order_date, customer_id
FROM my_ducklake.cust_orders;

-- now merge
MERGE INTO my_ducklake.cust_orders AS target
    USING my_ducklake.tmp_orders AS source
        ON target.order_id = source.order_id
    WHEN MATCHED THEN UPDATE 
    WHEN NOT MATCHED THEN INSERT BY NAME
;

SELECT '<< after merge >>' AS info;

-- view changes to the table 
SELECT *
FROM my_ducklake.cust_orders;