INSTALL iceberg; LOAD iceberg;
INSTALL aws; LOAD aws;
INSTALL httpfs; LOAD httpfs;

SET VARIABLE bucket = 'ducklake-definitive-guide';

CREATE SECRET aws_data (TYPE S3, PROVIDER credential_chain);

ATTACH getenv('AWS_ACCT_ID') as iceberg_datalake (
    TYPE iceberg,
    ENDPOINT_TYPE 'GLUE',
    PURGE_REQUESTED false
)
;

.print 'done';

DROP TABLE IF EXISTS iceberg_datalake.iceberg_db.test_2dot0;

CREATE TABLE iceberg_datalake.iceberg_db.test_2dot0 
WITH (location = concat('s3://', getvariable('bucket'), '/testlake'))
AS
SELECT id FROM range(0,5) as id
;

SELECT * FROM iceberg_datalake.iceberg_db.test_2dot0;