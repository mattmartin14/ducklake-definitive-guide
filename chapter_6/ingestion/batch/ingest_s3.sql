.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

INSTALL AWS; LOAD AWS;
CREATE SECRET (TYPE s3, PROVIDER credential_chain);
ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

CREATE TABLE dl1.orders (order_id integer, customer_id integer, order_date date);

INSERT INTO dl1.orders (order_id, customer_id, order_date)
SELECT o_orderkey, o_custkey, o_orderdate
FROM 's3://ducklake-definitive-guide/tpch/orders.parquet';

.print 'sample rows'
SELECT * FROM dl1.orders LIMIT 5;