
script=$(cat <<SQL

UPDATE EXTENSIONS;

ATTACH OR REPLACE 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH concat(getenv('HOME'), '/dw2'));

CREATE OR REPLACE SECRET aws_creds (TYPE S3, provider credential_chain);

ATTACH OR REPLACE '${aws_acct_nbr}' as iceberg_catalog (
      TYPE ICEBERG
    , ENDPOINT_TYPE 'GLUE'
);

Call iceberg_to_ducklake('iceberg_catalog', 'my_ducklake');

SQL
)  

echo $script

duckdb -s "$script"

#duckdb -f ./import_iceberg.sql

 # COPY FROM DATABASE iceberg_catalog.db3 TO my_ducklake;
# SELECT *
# from my_ducklake.db3.orders
# LIMIT 10;