#!/usr/bin/env bash
export glue_db_nm="db3"
export iceberg_wh_path="s3://${AWS_BUCKET}/iceberg_cat"

# Clean up any existing data in the S3 path and Glue catalog entries for iceberg_cat
aws s3 rm "$iceberg_wh_path" --recursive

# Delete the Iceberg Glue tables if they exist
if aws glue get-table --database-name "$glue_db_nm" --name "orders" >/dev/null 2>&1; then
  aws glue delete-table --database-name "$glue_db_nm" --name "orders"
fi

if aws glue get-table --database-name "$glue_db_nm" --name "order_lines" >/dev/null 2>&1; then
  aws glue delete-table --database-name "$glue_db_nm" --name "order_lines"
fi
echo "Cleaned up S3 path and Glue catalog entries for iceberg_cat"

script=$(envsubst < ./create_iceberg_cat.sql)
echo "$script"
duckdb -s "$script"



