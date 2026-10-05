/*
    This script assumes the following:
    1. You have a Google Cloud Storage bucket set up and have the bucket name under environment variable GCS_BUCKET.
    2. You have Google Cloud HMAC Keys set up, and the environment variables GCS_KEY, and GCS_SECRET are set.
    3. you have the gcloud CLI installed
*/

.shell rm -f -- "gcs_wh.ducklake"
.shell gcloud storage rm --recursive "gs://$GCS_BUCKET/ducklake/**"

CREATE SECRET gcs_creds (TYPE GCS, KEY_ID getenv('GCS_KEY'), SECRET getenv('GCS_SECRET'));

ATTACH 'ducklake:gcs_wh.ducklake' AS gcs_wh (DATA_PATH concat('gs://', getenv('GCS_BUCKET'), '/ducklake'));

CREATE TABLE gcs_wh.orders AS
SELECT ORDER_ID
FROM range(0, 50) AS t(ORDER_ID);

SELECT *
FROM gcs_wh.orders;