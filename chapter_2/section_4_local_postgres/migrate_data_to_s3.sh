
# 1 update the data path
duckdb <<SQL 
    CREATE SECRET aws_creds (TYPE S3, provider credential_chain);

    ATTACH 'ducklake:postgres:dbname=ducklake_v1 host=localhost' AS wh;
        --(DATA_PATH 's3://$AWS_BUCKET/ducklake_pg', OVERRIDE_DATA_PATH True); 
    
    UPDATE __ducklake_metadata_wh.ducklake_metadata
        SET value = 's3://$AWS_BUCKET/ducklake_pg/'
        where key = 'data_path'
    ;

    from __ducklake_metadata_wh.ducklake_metadata;
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

duckdb <<SQL 

    CREATE SECRET aws_creds (TYPE S3, provider credential_chain);

    ATTACH 'ducklake:postgres:dbname=ducklake_v1 host=localhost' AS wh;

    from __ducklake_metadata_wh.ducklake_metadata;

SQL 