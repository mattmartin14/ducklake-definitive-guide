.shell rm -f -- "ducklake_metadata.ducklake"
.shell aws s3 rm s3://ducklake-definitive-guide/alpha --recursive

INSTALL ducklake; LOAD ducklake;
INSTALL quack; LOAD quack;
INSTALL AWS; LOAD AWS;
INSTALL TPCH; LOAD TPCH;

CREATE OR REPLACE SECRET aws_s3 (TYPE S3, PROVIDER CREDENTIAL_CHAIN);

ATTACH 'ducklake:ducklake_metadata.ducklake' AS dl1 (
  DATA_PATH 's3://ducklake-definitive-guide/alpha'
);

CALL DBGEN(sf=.001);
CREATE SCHEMA dl1.tpch;
CREATE TABLE dl1.tpch.orders as SELECT * FROM ORDERS;

CALL quack_serve(token => 'test')