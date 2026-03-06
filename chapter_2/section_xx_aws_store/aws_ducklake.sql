CREATE OR REPLACE SECRET aws_creds (TYPE S3, PROVIDER credential_chain);

ATTACH OR REPLACE 'ducklake:aws_wh.ducklake' AS aws_wh
	(DATA_PATH concat('s3://', getenv('aws_bucket'), '/ducklake'));

CREATE OR REPLACE TABLE aws_wh.orders AS
SELECT 1 AS order_id, DATE '2024-01-01' AS order_date, 100.0 AS amount
UNION ALL
SELECT 2, DATE '2024-01-02', 150.0
UNION ALL
SELECT 3, DATE '2024-01-03', 201.0;

SELECT *
FROM aws_wh.orders;