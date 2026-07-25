INSTALL httpfs;
LOAD httpfs;

INSTALL iceberg;
LOAD iceberg;

INSTALL TPCH; LOAD TPCH;
CALL dbgen(sf=0.001);

CREATE OR REPLACE SECRET minio_secret (
    TYPE s3,
    PROVIDER config,
    KEY_ID 'minio',
    SECRET 'minio12345',
    REGION 'us-east-1',
    ENDPOINT 'localhost:9000',
    URL_STYLE 'path',
    USE_SSL false
);

ATTACH 'demo' AS lk (
    TYPE iceberg,
    ENDPOINT 'http://localhost:8181/catalog',
    AUTHORIZATION_TYPE 'none',
    ACCESS_DELEGATION_MODE 'none'
);

CREATE SCHEMA IF NOT EXISTS lk.demo_ns;

DROP TABLE IF EXISTS lk.demo_ns.orders;
CREATE TABLE lk.demo_ns.orders AS SELECT * FROM orders;
.print 'iceberg orders table created'


.print '-------------'
.print 'migrating to ducklake'

.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

FROM lk.demo_ns.orders WHERE 1=0;

COPY FROM DATABASE lk TO dl1;
.print 'iceberg catalog migrated to ducklake'

USE dl1;
select * from dl1.demo_ns.orders limit 5;

--select * from dl1.information_schema.tables;

--select * from dl1.demo_ns.orders limit 5;
