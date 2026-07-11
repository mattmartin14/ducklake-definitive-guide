.shell rm -f -- "frozen.ducklake"
.shell aws s3 rm s3://ducklake-definitive-guide/frozen/frozen.ducklake
.shell aws s3 rm s3://ducklake-definitive-guide/dw --recursive

INSTALL AWS; LOAD AWS;
CREATE SECRET (TYPE s3, PROVIDER credential_chain);
ATTACH 'ducklake:frozen.ducklake' as dl1 (DATA_PATH 's3://ducklake-definitive-guide/dw/', DATA_INLINING_ROW_LIMIT 0);

INSTALL TPCH; LOAD TPCH;
call dbgen(sf=.001);

CREATE TABLE dl1.orders AS
SELECT * 
FROM ORDERS;

-- DETACH flushes the WAL to disk; without this, aws s3 cp copies an empty 12 KB shell
-- this is crucial to ensure that all changes are written to disk before copying to S3
DETACH dl1;

.shell aws s3 cp frozen.ducklake s3://ducklake-definitive-guide/frozen/frozen.ducklake

.shell rm -f -- "frozen.ducklake"

