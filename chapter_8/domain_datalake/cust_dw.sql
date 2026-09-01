.shell rm -f -- "cust_dw.ducklake"
.shell rm -rf -- "./cust_dw"

ATTACH 'ducklake:cust_dw.ducklake' as cust (DATA_PATH './cust_dw');

ATTACH 'tpch.duckdb' as tpch;

CREATE TABLE cust.customer as
SELECT * FROM tpch.customer;