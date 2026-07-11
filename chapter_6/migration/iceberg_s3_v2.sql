
.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"


INSTALL aws; LOAD aws;
INSTALL iceberg; LOAD iceberg;
INSTALL httpfs; LOAD httpfs;
install tpch; load tpch;

call dbgen(sf=.001);

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0, AUTOMATIC_MIGRATION true);

CREATE SECRET aws_data (TYPE S3, PROVIDER credential_chain);

ATTACH 'arn:aws:s3tables:us-east-1:772434294110:bucket/icehouse-tbl-bucket1' AS iceberg_datalake (
            TYPE iceberg,
            ENDPOINT_TYPE s3_tables
        );

DROP TABLE IF EXISTS iceberg_datalake.ns1.orders;
DROP TABLE IF EXISTS iceberg_datalake.ns1.lineitem;
.print 'dropped iceberg tables'

CREATE TABLE iceberg_datalake.ns1.orders AS SELECT * FROM orders limit 5;
CREATE TABLE iceberg_datalake.ns1.lineitem AS SELECT * FROM lineitem limit 5;

.print 'created iceberg tables'

--SHOW TABLES FROM iceberg_datalake.ns1;

-- unless you pre-sample the tables here, you get an error when trying to migrate

-- filed bug here on deep copy: https://github.com/duckdb/ducklake/issues/1277
-- filed bug on shallow copy here: https://github.com/duckdb/ducklake/issues/1278

--from iceberg_datalake.ns1.orders limit 5;
--from iceberg_datalake.ns1.lineitem limit 5;

-- per the docs: https://ducklake.select/2025/09/17/ducklake-03/
--COPY FROM DATABASE iceberg_datalake TO dl1;

CALL iceberg_to_ducklake('iceberg_datalake','dl1');


