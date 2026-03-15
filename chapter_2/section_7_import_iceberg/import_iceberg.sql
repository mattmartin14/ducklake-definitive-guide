ATTACH OR REPLACE 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH concat(getenv('HOME'), '/dw2'));

INSTALL ICEBERG;
LOAD ICEBERG;

ATTACH '' AS iceberg_catalog (
        TYPE 'iceberg'
        , WAREHOUSE './icehouse'
        , AUTHORIZATION_TYPE 'none'
);

COPY FROM DATABASE iceberg_catalog TO my_ducklake;

SELECT *
from my_ducklake.purch_ord.orders
LIMIT 10;

-- it looks like local iceberg catalogs don't really work here; need to just use duckdb to create the iceberg catalog on aws glue
-- then import it over