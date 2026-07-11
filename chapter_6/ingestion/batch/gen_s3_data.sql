install aws; load aws;
install tpch; load tpch;

call dbgen(sf=.001);

create secret (type s3, provider credential_chain);

copy orders to 's3://ducklake-definitive-guide/tpch/orders.parquet';