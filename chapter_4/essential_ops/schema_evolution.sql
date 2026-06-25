.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw');

CREATE OR REPLACE TABLE dl1.sales
AS
SELECT 1 as sls_id, DATE '2025-01-01' as sls_dt, 200.05 as sls_amt, cast('North' as VARCHAR(30)) as region_name
UNION ALL
SELECT 2, DATE '2025-03-04', 153.75, cast('South' as VARCHAR(30));

-- adding a column
ALTER TABLE dl1.sales ADD cust_id INT DEFAULT -1;

-- cannot change a data type to a smaller one
-- ALTER TABLE dl1.sales ALTER cust_id SET TYPE SMALLINT;

-- changing a data type to a larger one
ALTER TABLE dl1.sales ALTER cust_id SET TYPE BIGINT;


-- renaming a table
ALTER TABLE dl1.sales RENAME TO sales_dly;

-- renaming a column
ALTER TABLE dl1.sales_dly RENAME cust_id TO customer_id;

-- drop a column
ALTER TABLE dl1.sales_dly DROP customer_id;

-- view results
FROM dl1.sales_dly;