.shell rm -f -- "local_inst.ducklake"

ATTACH OR REPLACE 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH concat(getenv('HOME'), '/dw1'));

CREATE OR REPLACE TABLE my_ducklake.cust_orders AS
SELECT * FROM 'customer_orders.csv';

SELECT * FROM my_ducklake.cust_orders;

