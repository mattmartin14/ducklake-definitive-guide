.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

/*
    Ducklake (as of April 2026) does not support merging with
     multiple WHEN MATCHED conditions
     e.g. 
     WHEN MATCHED and src.sls_amt <= 50 THEN DELETE 
     WHEN MATCHED and src.sls_amt > 50 THEN UPDATE

    also, does not support RETURNING clause to return what actions the merge statement took

*/

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw');

-- initialize base table
CREATE OR REPLACE TABLE dl1.sales
as
SELECT 1 as sls_id, DATE '2025-01-01' as sls_dt, 200.05 as sls_amt
UNION ALL
SELECT 2, DATE '2025-03-04', 153.75;

-- create staging table
CREATE OR REPLACE table tmp_sales
AS
SELECT 2 as sls_id, Date '2025-03-04' as sls_dt, 140.05 as sls_amt
UNION ALL
SELECT 3, date '2025-08-02', 332.12;

-- simple merge
MERGE INTO dl1.sales as tgt
    USING tmp_sales as src
        ON tgt.sls_id = src.sls_id
    WHEN MATCHED THEN UPDATE
    WHEN NOT MATCHED THEN INSERT
  ;

-- merge with columns typed
MERGE INTO dl1.sales as tgt
    USING tmp_sales as src
        ON tgt.sls_id = src.sls_id
    WHEN MATCHED THEN UPDATE
        SET sls_dt = src.sls_dt, sls_amt = src.sls_amt
    WHEN NOT MATCHED THEN 
        INSERT (sls_id, sls_dt, sls_amt)
        VALUES (src.sls_id, src.sls_dt, src.sls_amt)
;

-- merge delete on match
MERGE INTO dl1.sales as tgt
    USING tmp_sales as src
        ON tgt.sls_id = src.sls_id
    WHEN MATCHED THEN DELETE 
;


-- merge delete multiple scenarios
MERGE INTO dl1.sales as tgt
    USING tmp_sales as src
        ON tgt.sls_id = src.sls_id
    WHEN NOT MATCHED BY SOURCE THEN DELETE -- rec doesnt exist in source, delete target entry
    WHEN NOT MATCHED BY TARGET THEN INSERT -- doenst exist in target, insert
;

-- delete with conditional
MERGE INTO dl1.sales as tgt
    USING tmp_sales as src
        ON tgt.sls_id = src.sls_id
    WHEN MATCHED and src.sls_amt <= 50 THEN DELETE 
;

-- update with conditional
MERGE INTO dl1.sales as tgt
    USING tmp_sales as src
        ON tgt.sls_id = src.sls_id
    WHEN MATCHED and src.sls_amt <= 50 THEN UPDATE 
;


-- insert with conditional
MERGE INTO dl1.sales as tgt
    USING tmp_sales as src
        ON tgt.sls_id = src.sls_id
    WHEN NOT MATCHED and src.sls_amt <= 50 THEN INSERT 
;

FROM dl1.sales;