ATTACH 'ducklake:../section_2_importing_data/local_inst.ducklake' as my_ducklake;

INSERT INTO my_ducklake.cust_orders
VALUES (1004, '2024-01-04', 'C004');

UPDATE my_ducklake.cust_orders
SET order_date = '2024-01-05'
WHERE order_id = 1004;

DELETE FROM my_ducklake.cust_orders
WHERE order_id = 1003;

SELECT *
FROM my_ducklake.cust_orders;