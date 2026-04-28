.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw');

CREATE OR REPLACE TABLE dl1.sales
as
SELECT 1 as sls_id, DATE '2025-01-01' as sls_dt, 200.05 as sls_amt
UNION ALL
SELECT 2, DATE '2025-03-04', 153.75;

-- adding a column
alter table dl1.sales add cust_id int;

-- cannot change a data type to a smaller one
-- alter table dl1.sales alter cust_id set type smallint;

-- changing a data type to a larger one
alter table dl1.sales alter cust_id set type bigint;

-- renaming a table
alter table dl1.sales rename to sales_dly;

-- renaming a column
alter table dl1.sales_dly rename cust_id to customer_id;

-- drop a column
alter table dl1.sales_dly drop customer_id;

-- view results
from dl1.sales_dly;