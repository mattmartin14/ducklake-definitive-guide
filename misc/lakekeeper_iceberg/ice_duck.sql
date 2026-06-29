INSTALL httpfs;
LOAD httpfs;

INSTALL iceberg;
LOAD iceberg;

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

DROP TABLE IF EXISTS lk.demo_ns.sales;

CREATE TABLE lk.demo_ns.sales (
    sale_id INTEGER,
    customer_name VARCHAR,
    sale_amount DECIMAL(10,2),
    sale_ts TIMESTAMP
);

INSERT INTO lk.demo_ns.sales VALUES
    (1, 'matt', 100.25, TIMESTAMP '2026-06-28 08:00:00'),
    (2, 'jane', 225.50, TIMESTAMP '2026-06-28 09:00:00'),
    (3, 'duck',  42.00, TIMESTAMP '2026-06-28 10:00:00');

SELECT *
FROM lk.demo_ns.sales
ORDER BY sale_id;

SELECT
    COUNT(*) AS row_count,
    SUM(sale_amount) AS total_sales
FROM lk.demo_ns.sales;