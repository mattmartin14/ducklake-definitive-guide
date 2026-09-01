.shell rm -f -- "sales_dw.ducklake"
.shell rm -rf -- "./sls_dw"

ATTACH 'ducklake:sales_dw.ducklake' as sls (DATA_PATH './sls_dw');

ATTACH 'tpch.duckdb' as tpch;

CREATE TABLE sls.orders as
SELECT * FROM tpch.orders;

