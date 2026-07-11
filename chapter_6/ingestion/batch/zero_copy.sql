.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"
.shell mkdir -p -- "./tpch"

install tpch; load tpch;
CALL dbgen(sf=.001);
install aws; load aws;

CREATE SECRET (TYPE s3, PROVIDER credential_chain);

COPY orders to './tpch/orders.parquet';
COPY ORDERS to 's3://ducklake-definitive-guide/tpch/orders.parquet';



ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

.print 'cloning metadata from tpch/orders.parquet'
CREATE TABLE dl1.orders_from_local as SELECT * FROM './tpch/orders.parquet' LIMIT 0;
CREATE TABLE dl1.orders_from_s3 as SELECT * FROM 's3://ducklake-definitive-guide/tpch/orders.parquet' LIMIT 0;


CALL ducklake_add_data_files('dl1', 'orders_from_local', './tpch/orders.parquet');
CALL ducklake_add_data_files('dl1', 'orders_from_s3', 's3://ducklake-definitive-guide/tpch/orders.parquet');

.print 'sample rows'
SELECT * FROM dl1.orders_from_local LIMIT 5;
SELECT * FROM dl1.orders_from_s3 LIMIT 5;



