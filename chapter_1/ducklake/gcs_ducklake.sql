CREATE OR REPLACE SECRET gcs_creds (TYPE GCS, KEY_ID getenv('GCS_KEY'), SECRET getenv('GCS_SECRET'));

ATTACH OR REPLACE 'ducklake:gcs_wh.ducklake' AS gcs_wh (DATA_PATH concat('gs://', getenv('GCS_BUCKET'), '/ducklake'));

CREATE OR REPLACE TABLE gcs_wh.orders AS
SELECT 1 AS order_id, DATE '2024-01-01' AS order_date, 100.0 AS amount
UNION ALL
SELECT 2, DATE '2024-01-02', 150.0
UNION ALL
SELECT 3, DATE '2024-01-03', 200.0;

SELECT *
FROM gcs_wh.orders;