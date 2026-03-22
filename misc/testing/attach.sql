ATTACH OR REPLACE 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH concat(getenv('HOME'), '/dw2'));

INSTALL ICEBERG;
LOAD ICEBERG;

CREATE OR REPLACE SECRET aws_creds (TYPE S3, provider credential_chain);

ATTACH getenv('AWS_ACCT_ID') AS iceberg_catalog (
      TYPE ICEBERG
    , ENDPOINT_TYPE 'GLUE'
);