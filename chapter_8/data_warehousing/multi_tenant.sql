.shell rm -f -- "local_inst.ducklake"
.shell aws s3 rm s3://ducklake-definitive-guide/dw --recursive

CREATE SECRET s3_creds (TYPE S3, PROVIDER CREDENTIAL_CHAIN);

INSTALL TPCH; LOAD TPCH;
CALL dbgen(sf=.001);
ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH 's3://ducklake-definitive-guide/dw');

CREATE SCHEMA dl1.sales;
CREATE SCHEMA dl1.finance;

CREATE TABLE dl1.sales.orders AS
SELECT * FROM orders;

CREATE TABLE dl1.finance.customers AS
SELECT * FROM customer;