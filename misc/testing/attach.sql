.shell rm -rf ./dw2

CALL enable_peg_parser();

ATTACH OR REPLACE 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH './dw2');

INSTALL ICEBERG;
LOAD ICEBERG;

select version();

CREATE OR REPLACE SECRET aws_creds (TYPE S3, provider credential_chain);

ATTACH getenv('aws_acct_nbr') AS iceberg_catalog (
      TYPE ICEBERG
    , ENDPOINT_TYPE 'GLUE'
);

SELECT * FROM iceberg_catalog.db3.order_lines;