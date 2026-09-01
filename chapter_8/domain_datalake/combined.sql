
ATTACH 'ducklake:cust_dw.ducklake' as cust (DATA_PATH './cust_dw');
ATTACH 'ducklake:sales_dw.ducklake' as sls (DATA_PATH './sls_dw');

SELECT c.c_name, o.o_orderkey, o.o_orderdate
FROM cust.customer as c
    JOIN sls.orders as o
        ON c.c_custkey = o.o_custkey
LIMIT 5
;