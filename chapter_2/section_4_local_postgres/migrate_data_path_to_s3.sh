
# 1 update the data path
duckdb <<SQL 
    CREATE SECRET aws_creds (TYPE S3, provider credential_chain);

    ATTACH OR REPLACE 'ducklake:postgres:dbname=ducklake_v1 host=localhost' AS wh 
    (DATA_PATH concat('s3://', getenv('aws_bucket'), '/ducklake_pg'), OVERRIDE_DATA_PATH True); 
SQL

echo "Data path updated to S3 bucket: $AWS_BUCKET/ducklake_pg"

# 2 migrate the local data
aws s3 cp "$HOME/dwpg1/" "s3://$AWS_BUCKET/ducklake_pg/" --recursive


echo "Data migrated to S3 bucket: $AWS_BUCKET/ducklake_pg"

# 3 query to test
duckdb <<SQL 

    CREATE SECRET aws_creds (TYPE S3, provider credential_chain);

    ATTACH 'ducklake:postgres:dbname=ducklake_v1 host=localhost' AS wh;

    SELECT * FROM wh.orders;
SQL