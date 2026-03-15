#!/usr/bin/env bash

s3_path="s3://${aws_bucket}/iceberg_cat"
glue_db_nm="db3"

aws s3 rm "$s3_path" --recursive
if aws glue get-table --database-name "$glue_db_nm" --name "orders" >/dev/null 2>&1; then
  aws glue delete-table --database-name "$glue_db_nm" --name "orders"
fi

if aws glue get-table --database-name "$glue_db_nm" --name "order_lines" >/dev/null 2>&1; then
  aws glue delete-table --database-name "$glue_db_nm" --name "order_lines"
fi
echo "Cleaned up S3 path and Glue catalog entries for iceberg_cat"

script=$(cat <<SQL

CREATE OR REPLACE SECRET aws_creds (TYPE S3, provider credential_chain);

ATTACH OR REPLACE '${aws_acct_nbr}' as iceberg_catalog (
      TYPE ICEBERG
    , ENDPOINT_TYPE 'GLUE'
);

CREATE TABLE iceberg_catalog.db3.orders 
WITH (
  'location' = 's3://${AWS_BUCKET}/iceberg_cat/iceberg_orders'
)
AS
SELECT 1001 as order_id, DATE '2024-01-01' AS order_date, 'C001' AS customer_id, 250.0 as total_amount
UNION ALL
SELECT 1002, DATE '2024-01-02', 'C002', 150
;

CREATE TABLE iceberg_catalog.db3.order_lines
WITH (
  'location' = 's3://${AWS_BUCKET}/iceberg_cat/iceberg_order_lines'
)
AS
SELECT 1 as order_line_id, 1001 as order_id, 'P001' as product_id, 2 as quantity, 125.0 as line_total
UNION ALL
SELECT 2, 1001, 'P002', 1, 125
UNION ALL
SELECT 3, 1002, 'P001', 1, 125
UNION ALL
SELECT 4, 1002, 'P003', 1, 250
;
SQL
)

duckdb -s "$script"



