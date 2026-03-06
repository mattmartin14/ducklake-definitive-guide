ATTACH 'ducklake:local_inst.ducklake' as my_ducklake;

-- view before
SELECT * 
FROM my_ducklake.cust_orders
;

CREATE OR REPLACE TABLE my_ducklake.tmp_orders AS
SELECT order_id, date_add(order_date, INTERVAL '1 day') AS order_date, customer_id
FROM my_ducklake.cust_orders;

MERGE INTO my_ducklake.cust_orders AS target
    USING my_ducklake.tmp_orders AS source
        ON target.order_id = source.order_id
    WHEN MATCHED THEN UPDATE 
    WHEN NOT MATCHED THEN INSERT BY NAME
;

-- view after
SELECT * 
FROM my_ducklake.cust_orders